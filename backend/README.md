# Ayurvedic Urine Test - Backend

This folder contains the Python backend for the digitized Ayurvedic Urine Test (Taila Bindu Pariksha).

## Setup

1.  **Install Python 3.x**
2.  **Install Dependencies**:
    ```bash
    pip install -r requirements.txt
    ```
3.  **Setup MySQL Database**:
    - Make sure you have MySQL installed and running.
    - Create a database (e.g., `ayurveda_db`).
    - Update `app.py` with your MySQL credentials (`db_config`).
    - Run the schema script:
      ```bash
      mysql -u root -p < db_schema.sql
      ```

## Running the Server

```bash
python app.py
```

The server will start on `http://localhost:5000`.

## API Endpoints

### 1. Upload Test Video
- **URL**: `/api/upload_test`
- **Method**: `POST`
- **Body** (Multipart Form Data):
    - `video`: The video file (e.g., `.mp4`, `.avi`).
    - `patient_id`: The ID of the patient.
- **Response**: JSON containing calculated Speed, Direction, and Shape.

## Project Structure

- `app.py`: Flask application server.
- `vision_engine.py`: Computer Vision logic using OpenCV.
- `db_schema.sql`: Database table definitions.
- `uploads/`: Directory where uploaded videos are saved.
