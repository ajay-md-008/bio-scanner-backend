from flask import Flask, request, jsonify
import mysql.connector
from vision_engine import OilDropAnalyzer
import os
import cv2

app = Flask(__name__)

# Database Configuration
# Database Configuration
# Cloud Deployment: Use Environment Variables or fallback
host = os.environ.get('DB_HOST', 'localhost')
user = os.environ.get('DB_USER', 'root')
password = os.environ.get('DB_PASSWORD', 'jose')
port = int(os.environ.get('DB_PORT', 3308))
database = os.environ.get('DB_NAME', 'ayurveda_db')

db_config = {
    'user': user,
    'password': password,
    'host': host,
    'port': port,
    'database': database
}

UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "healthy"}), 200

@app.route('/api/upload_test', methods=['POST'])
def upload_test():
    if 'video' not in request.files:
        return jsonify({"error": "No video file provided"}), 400
    
    video = request.files['video']
    patient_id = request.form.get('patient_id')
    
    if not patient_id:
         return jsonify({"error": "Patient ID required"}), 400

    video_path = os.path.join(UPLOAD_FOLDER, video.filename)
    video.save(video_path)

    # Process Video
    try:
        analyzer = OilDropAnalyzer()
        results = analyzer.analyze_video(video_path)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": f"Vision Engine Failed: {str(e)}"}), 500

    # Save to DB (only if analysis succeeded)
    save_to_db(patient_id, video_path, results)

    return jsonify({
        "message": "Analysis Complete",
        "results": results
    })

def save_to_db(patient_id, video_path, results):
    try:
        conn = mysql.connector.connect(**db_config)
        cursor = conn.cursor()
        query = ("INSERT INTO tests (patient_id, video_path, spreading_speed, spreading_direction, shape_detected) "
                 "VALUES (%s, %s, %s, %s, %s)")
        data = (patient_id, video_path, results['speed'], results['direction'], results['shape'])
        cursor.execute(query, data)
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Database error (Data not saved): {e}")
        # On Cloud/Render without a DB, we just print the error 
        # so the analysis still returns results to the app.

@app.route('/', methods=['GET'])
def index():
    return jsonify({
        "status": "online",
        "message": "Ayurveda Bio Scanner API is running.",
        "endpoints": ["/health", "/api/upload_test"]
    }), 200

if __name__ == '__main__':
    # host='0.0.0.0' is CRITICAL for mobile capabilities
    app.run(debug=True, port=5000, host='0.0.0.0')
