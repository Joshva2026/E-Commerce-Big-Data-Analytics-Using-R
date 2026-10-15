import os
import cgi
import json
import subprocess
from http.server import SimpleHTTPRequestHandler, HTTPServer
import shutil

PORT = int(os.environ.get("PORT", 8001))
BIND = "0.0.0.0"
DATA_DIR = os.path.join(os.getcwd(), "data")
UPLOADED_FILE_PATH = os.path.join(DATA_DIR, "uploaded_dataset.csv")

# Dynamic discovery of Rscript executable for Windows and POSIX
RSCRIPT_PATH = os.environ.get("RSCRIPT_PATH")
if not RSCRIPT_PATH:
    which_r = shutil.which("Rscript")
    if which_r:
        RSCRIPT_PATH = which_r
    else:
        # Check standard Windows installation directories
        candidates = [
            r"C:\Program Files\R\R-4.6.1\bin\Rscript.exe",
            r"C:\Program Files\R\R-4.6.0\bin\Rscript.exe",
            r"C:\Program Files\R\R-4.5.0\bin\Rscript.exe",
        ]
        import glob
        globbed = sorted(glob.glob(r"C:\Program Files\R\R-*\bin\Rscript.exe"), reverse=True)
        candidates.extend(globbed)
        for cand in candidates:
            if os.path.exists(cand):
                RSCRIPT_PATH = cand
                break
        if not RSCRIPT_PATH:
            RSCRIPT_PATH = "Rscript"
RUN_SCRIPT = "run_analysis.R"

# Upload and timeout limits (configured for local big data processing)
MAX_UPLOAD_SIZE_MB = int(os.environ.get("MAX_UPLOAD_SIZE_MB", 250))
MAX_UPLOAD_BYTES = MAX_UPLOAD_SIZE_MB * 1024 * 1024
R_TIMEOUT_SECONDS = int(os.environ.get("R_TIMEOUT_SECONDS", 300))

# Local CORS Policy: Permit localhost, 127.0.0.1, same-origin, and file://
def is_origin_allowed(origin):
    if not origin or origin == "null" or "localhost" in origin or "127.0.0.1" in origin:
        return True
    return False

# Ensure data dir exists
os.makedirs(DATA_DIR, exist_ok=True)

import mimetypes
mimetypes.add_type('application/json', '.json')
mimetypes.add_type('application/javascript', '.js')
mimetypes.add_type('text/css', '.css')

class AnalyticsRequestHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        # Clean query parameters for route checks
        clean_path = self.path.split('?')[0]
        if clean_path in ['/', '', '/web', '/web/']:
            self.send_response(302)
            self.send_header('Location', '/web/index.html')
            self.end_headers()
            return
        elif clean_path == '/api/status':
            self.send_json_response({
                "status": "online",
                "service": "E-Commerce Big Data Analytics R Backend",
                "engine": "R 4.6.1 (or active Rscript)",
                "server": "Python local_server",
                "port": PORT,
                "project_root": os.getcwd(),
                "storage": {
                    "demo_dataset": os.path.exists(os.path.join(DATA_DIR, "indian_ecommerce_data.csv")),
                    "advanced_dataset": os.path.exists(os.path.join(os.getcwd(), "datasets", "advanced_ecommerce_dataset.csv"))
                }
            })
            return
        super().do_GET()


    def do_POST(self):
        clean_path = self.path.split('?')[0]
        if clean_path == '/api/upload':
            self.handle_upload()
        elif clean_path == '/api/reset':
            self.handle_reset()
        elif clean_path == '/api/builtin':
            self.handle_builtin()
        elif clean_path == '/api/status':
            self.send_json_response({
                "status": "online",
                "engine": "R 4.6.1 (x86_64-w64-mingw32)",
                "server": "Python local_server",
                "port": PORT
            })
        else:
            self.send_error(404, "Endpoint not found")

    def handle_upload(self):
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length > MAX_UPLOAD_BYTES:
                self.send_json_response({
                    "success": False, 
                    "message": f"Uploaded dataset exceeds the maximum configured size limit of {MAX_UPLOAD_SIZE_MB} MB."
                }, 413)
                return

            content_type = self.headers.get('Content-Type', '')
            if not content_type.startswith('multipart/form-data'):
                self.send_json_response({"success": False, "message": "Invalid content type. Expected multipart/form-data."}, 400)
                return

            # Read the file

            form = cgi.FieldStorage(
                fp=self.rfile,
                headers=self.headers,
                environ={'REQUEST_METHOD': 'POST',
                         'CONTENT_TYPE': self.headers['Content-Type'],
                         }
            )

            file_item = None
            for key in ['dataset', 'file', 'upload', 'data']:
                if key in form:
                    item = form[key]
                    if isinstance(item, list) and len(item) > 0:
                        file_item = item[0]
                    else:
                        file_item = item
                    break

            if file_item is None:
                self.send_json_response({"success": False, "message": "No valid dataset file provided in upload request."}, 400)
                return

            raw_filename = getattr(file_item, 'filename', None)
            if not raw_filename:
                self.send_json_response({"success": False, "message": "No valid filename found in uploaded dataset."}, 400)
                return

            if getattr(file_item, 'file', None) is None:
                self.send_json_response({"success": False, "message": "Uploaded file stream is empty."}, 400)
                return

            filename = os.path.basename(raw_filename)
            ext = os.path.splitext(filename)[1].lower()
            
            if ext not in ['.csv', '.xlsx', '.xls']:
                self.send_json_response({"success": False, "message": f"Unsupported file extension '{ext}'. Please upload CSV or XLSX."}, 400)
                return
                
            saved_path = os.path.join(DATA_DIR, f"uploaded_dataset{ext}")
            with open(saved_path, 'wb') as f:
                shutil.copyfileobj(file_item.file, f)

            # Run R pipeline
            success, msg_or_dict = self.run_r_pipeline(saved_path, filename)
            
            if success:
                self.send_json_response({
                    "success": True,
                    "message": "Dataset processed successfully.",
                    "analytics_file": "output/analytics.json"
                })
            else:
                if isinstance(msg_or_dict, dict):
                    err_msg = msg_or_dict.get('message') or msg_or_dict.get('reason') or "Validation Error in R pipeline"
                    self.send_json_response({"success": False, "error_type": "validation", "message": err_msg, "details": msg_or_dict}, 400)
                else:
                    self.send_json_response({"success": False, "error_type": "system", "message": str(msg_or_dict)}, 500)

        except Exception as e:
            self.send_json_response({"success": False, "message": f"Server upload exception: {str(e)}"}, 500)

    def handle_reset(self):
        try:
            for ext in ['.csv', '.xlsx', '.xls']:
                p = os.path.join(DATA_DIR, f"uploaded_dataset{ext}")
                if os.path.exists(p):
                    os.remove(p)
                    
            success, msg = self.run_r_pipeline("data/indian_ecommerce_data.csv", "indian_ecommerce_data.csv")
            if success:
                self.send_json_response({
                    "success": True, 
                    "message": "Dataset processed successfully.",
                    "analytics_file": "output/analytics.json"
                })
            else:
                self.send_json_response({"success": False, "message": msg}, 500)
        except Exception as e:
            self.send_json_response({"success": False, "message": str(e)}, 500)

    def handle_builtin(self):
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            payload = json.loads(post_data.decode('utf-8'))
            filename = payload.get('filename')
            
            if not filename or not filename.endswith('.csv'):
                self.send_json_response({"success": False, "message": "Invalid built-in filename"}, 400)
                return
                
            filepath = os.path.join(DATA_DIR, filename)
            if not os.path.exists(filepath):
                self.send_json_response({"success": False, "message": "Built-in dataset not found"}, 404)
                return
                
            for ext in ['.csv', '.xlsx', '.xls']:
                p = os.path.join(DATA_DIR, f"uploaded_dataset{ext}")
                if os.path.exists(p):
                    os.remove(p)
                    
            success, msg = self.run_r_pipeline(f"data/{filename}", filename)
            if success:
                self.send_json_response({
                    "success": True, 
                    "message": "Dataset processed successfully.",
                    "analytics_file": "output/analytics.json"
                })
            else:
                self.send_json_response({"success": False, "message": msg}, 500)
        except Exception as e:
            self.send_json_response({"success": False, "message": str(e)}, 500)

    def run_r_pipeline(self, filepath, original_name):
        import time
        start_time = time.time()
        
        # Ensure cwd is project root
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        
        cmd = [RSCRIPT_PATH, RUN_SCRIPT, filepath, original_name]
        
        log_path = os.path.join(project_root, "output", "server_debug.log")
        
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] EXECUTING: {' '.join(cmd)}\n")
            f.write(f"Input: {filepath}\n")
            f.write(f"CWD: {project_root}\n")
            
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=project_root, timeout=R_TIMEOUT_SECONDS)
            duration = time.time() - start_time
        except subprocess.TimeoutExpired:
            duration = time.time() - start_time
            with open(log_path, "a", encoding="utf-8") as f:
                f.write(f"TIMEOUT EXPIRED after {duration:.2f}s\n")
                f.write("-" * 80 + "\n")
            return False, {
                "error_type": "TIMEOUT_ERROR",
                "message": f"R analytics pipeline timed out after {R_TIMEOUT_SECONDS}s. Dataset may exceed single-run execution limits."
            }
            
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"Exit Code: {result.returncode}\n")
            f.write(f"Duration: {duration:.2f}s\n")
            f.write(f"STDOUT:\n{result.stdout}\n")
            f.write(f"STDERR:\n{result.stderr}\n")
            f.write("-" * 80 + "\n")
            
        if result.returncode == 0:
            # Validate analytics.json exists and is valid
            analytics_path = os.path.join(project_root, "output", "analytics.json")
            if not os.path.exists(analytics_path):
                return False, {
                    "error_type": "ANALYTICS_OUTPUT_ERROR",
                    "message": "R completed but analytics.json was not generated correctly."
                }
            try:
                with open(analytics_path, "r", encoding="utf-8") as af:
                    json.load(af)
            except Exception as je:
                return False, {
                    "error_type": "ANALYTICS_OUTPUT_ERROR",
                    "message": f"analytics.json is invalid JSON: {str(je)}"
                }
            
            return True, "Analysis complete."
        else:
            stderr = result.stderr
            # Try to extract JSON from stderr
            import re
            match = re.search(r'\{.*\}', stderr, re.DOTALL)
            if match:
                try:
                    err_dict = json.loads(match.group(0))
                    return False, err_dict
                except:
                    pass
            
            # Check for clean "Validation Error" without JSON
            if "Validation Error:" in stderr:
                for line in stderr.split('\n'):
                    if "Validation Error:" in line:
                        return False, {"reason": line.split("Validation Error:")[1].strip()}

            # Structured unknown error containing stdout/stderr
            return False, {
                "error_type": "R_EXECUTION_ERROR",
                "message": "R analysis failed.",
                "return_code": result.returncode,
                "stderr": result.stderr.strip()[-500:], # limit size for browser
                "stdout": result.stdout.strip()[-500:]
            }

    def end_headers(self):
        req_origin = self.headers.get('Origin', '')
        if is_origin_allowed(req_origin):
            self.send_header('Access-Control-Allow-Origin', req_origin if req_origin and req_origin != 'null' else '*')
            if req_origin and req_origin != 'null':
                self.send_header('Access-Control-Allow-Credentials', 'true')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Range, X-Requested-With')
        self.send_header('Access-Control-Max-Age', '86400')
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()


    def send_json_response(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

    def send_json_error(self, message, status=400):
        self.send_json_response({"status": "error", "message": message}, status)

if __name__ == '__main__':
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(project_root)
    analytics_path = os.path.join(project_root, "output", "analytics.json")
    if not os.path.exists(analytics_path) or os.path.getsize(analytics_path) == 0:
        print("Pre-warming analytics contract from baseline dataset...")
        try:
            subprocess.run([RSCRIPT_PATH, RUN_SCRIPT, "data/indian_ecommerce_data.csv", "indian_ecommerce_data.csv"], cwd=project_root)
        except Exception as e:
            print(f"Pre-warm notice: {e}")

    HTTPServer.allow_reuse_address = True
    server = HTTPServer(('', PORT), AnalyticsRequestHandler)
    print(f"Starting controlled server on port {PORT} (http://localhost:{PORT} and http://127.0.0.1:{PORT})")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
        server.server_close()

