import cv2
import numpy as np
import math

class OilDropAnalyzer:
    def __init__(self):
        # Parameters for analysis
        self.frame_rate = 30 
        self.pixel_to_mm_scale = 1.0
        
        # Load ML Model if available
        self.model = None
        try:
            import joblib
            model_path = "oil_shape_model.pkl"
            if os.path.exists(model_path):
                self.model = joblib.load(model_path)
                print("ML Model loaded successfully.")
            else:
                print("ML Model not found. Using Heuristics.")
        except Exception as e:
            print(f"Error loading model: {e}")

    # ... existing analyze_video and detect_drop methods ...

    def extract_features(self, contour):
        """Helper to extract features matching the training script"""
        area = cv2.contourArea(contour)
        if area == 0: return None
        
        # 1. Hu Moments
        moments = cv2.moments(contour)
        hu_moments = cv2.HuMoments(moments).flatten()
        # Log transform safely
        hu_moments = -np.sign(hu_moments) * np.log10(np.abs(hu_moments) + 1e-10)

        # 2. Solidity
        hull = cv2.convexHull(contour)
        hull_area = cv2.contourArea(hull)
        solidity = float(area) / hull_area if hull_area > 0 else 0

        # 3. Aspect Ratio
        x, y, w, h = cv2.boundingRect(contour)
        aspect_ratio = float(w) / h

        # 4. Circularity
        perimeter = cv2.arcLength(contour, True)
        circularity = (4 * np.pi * area) / (perimeter ** 2) if perimeter > 0 else 0

        return np.hstack([hu_moments, [solidity, aspect_ratio, circularity]])

    def classify_shape(self, contour):
        # 1. Try ML Prediction
        if self.model:
            try:
                features = self.extract_features(contour)
                if features is not None:
                    # Reshape for single sample
                    prediction = self.model.predict([features])[0]
                    # Get probability if possible (optional)
                    return prediction
            except Exception as e:
                print(f"ML Prediction failed: {e}")

        # 2. Fallback to Heuristics
        perimeter = cv2.arcLength(contour, True)
        area = cv2.contourArea(contour)
        if perimeter == 0: return "Unknown"
        
        circularity = 4 * math.pi * (area / (perimeter * perimeter))
        x, y, w, h = cv2.boundingRect(contour)
        aspect_ratio = float(w) / h
        hull = cv2.convexHull(contour)
        hull_area = cv2.contourArea(hull)
        solidity = float(area) / hull_area if hull_area > 0 else 0

        # Classification Logic (Heuristics)
        if circularity > 0.85:
            return "Pearl (Circular)"
        elif circularity > 0.70:
            return "Elliptical"
        elif solidity < 0.7:
             return "Irregular"
        elif aspect_ratio > 3 or aspect_ratio < 0.33:
            return "Snake"
        else:
            return "Ring"
            
    def analyze_video(self, video_path):
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            return {"error": "Could not open video"}
        
        self.frame_rate = cap.get(cv2.CAP_PROP_FPS) or 30
        
        frame_count = 0
        initial_area = 0
        final_area = 0
        initial_centroid = None
        final_centroid = None
        
        # Lists to track history
        areas = []
        centroids = []
        shapes_detected = []

        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            frame_count += 1
            # Skip frames (process every 15th frame = ~2fps)
            if frame_count % 15 != 0:
                continue

            # Resize frame for faster processing (Width: 640px)
            height, width = frame.shape[:2]
            if width > 640:
                scale_factor = 640 / width
                new_height = int(height * scale_factor)
                frame = cv2.resize(frame, (640, new_height))

            # 1. Preprocessing & Detection
            contour = self.detect_drop(frame)
            
            if contour is not None:
                # 2. Extract Features
                area = cv2.contourArea(contour)
                M = cv2.moments(contour)
                if M["m00"] != 0:
                    cX = int(M["m10"] / M["m00"])
                    cY = int(M["m01"] / M["m00"])
                    centroid = (cX, cY)
                else:
                    centroid = None

                # Store data
                areas.append(area)
                centroids.append(centroid)
                
                # Dynamic Shape Classification per frame (or just final frame)
                shape = self.classify_shape(contour)
                shapes_detected.append(shape)

                if initial_area == 0:
                    initial_area = area
                    initial_centroid = centroid
                
                final_area = area
                final_centroid = centroid
                
            # Store the last successfully read frame for final analysis
            # We use .copy() to ensure we have the raw data even if loop variables change
            # But 'frame' inside loop is valid here.
            last_valid_frame = frame 

        cap.release()

        if not areas:
            return {"error": "No oil drop detected (Video might be empty or too dark)"}

        # 3. Calculate Speed
        # Speed = Change in Area / Time
        duration_sec = (frame_count / self.frame_rate)
        speed = (final_area - initial_area) / duration_sec if duration_sec > 0 else 0
        
        # 4. Calculate Direction
        direction = self.determine_direction(initial_centroid, final_centroid)

        # 5. Final Shape (Most frequent or last detected)
        final_shape = shapes_detected[-1] if shapes_detected else "Unknown"

        # 6. Calculate Detailed Metrics (Based on User Formulas)
        # Using the final contour for these calculations
        circularity = 0
        irregularity = 0
        perimeter = 0 # Initialize perimeter
        
        if final_area > 0 and last_valid_frame is not None:
             # Use the last valid frame for the final contour check
             final_drop_contour = self.detect_drop(last_valid_frame)
             if final_drop_contour is not None:
                perimeter = cv2.arcLength(final_drop_contour, True)
                if perimeter > 0:
                    circularity = (4 * math.pi * final_area) / (perimeter ** 2)
                    irregularity = 1.0 / circularity if circularity > 0 else 0
        
        # Ensure calculated values are safe


        # Interpretation based on User's Note
        # Circularity ~ 1 => Healthy
        # Circularity <= 0.6 => Irregular
        
        return {
            "speed": round(speed, 2),
            "direction": direction,
            "shape": final_shape,
            "duration_sec": round(duration_sec, 2),
            "circularity": round(circularity, 2),
            "irregularity": round(irregularity, 2),
            "area_px": int(final_area),
            "perimeter_px": int(perimeter) if 'perimeter' in locals() else 0
        }

    def detect_drop(self, frame):
        if frame is None or frame.size == 0:
            return None
            
        # Convert to HSV color space
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        
        # Analyze central part of image to find oil color automatically?
        # For now, assume oil is darker/yellowish against urine background.
        # Ideally, we used fixed thresholds or adaptive thresholding.
        
        # Using Grayscale + Otsu's Thresholding (Robust for contrast)
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        
        # Threshold: Oil drop is usually distinct from liquid
        # Note: Depending on lighting, oil might be lighter or darker.
        # INVERSE thresholding might be needed if oil is dark on light background.
        ret, thresh = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        
        # Morphological operations to remove noise
        kernel = np.ones((3,3), np.uint8)
        thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=2)
        
        # Find Contours
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        if contours:
            # Assume largest contour is the oil drop
            largest_contour = max(contours, key=cv2.contourArea)
            if cv2.contourArea(largest_contour) > 100: # Min area filter
                return largest_contour
        
        return None

    def determine_direction(self, start_point, end_point):
        if not start_point or not end_point:
            return "Stationary"
        
        dx = end_point[0] - start_point[0]
        dy = end_point[1] - start_point[1] # Y is inverted in images (down is positive)
        
        # Euclidean distance
        distance = math.sqrt(dx**2 + dy**2)
        if distance < 10: # Threshold for movement
            return "Stationary"

        # Calculate angle against North (Up)
        # In image coords: Up is -Y, Right is +X
        angle_rad = math.atan2(-dy, dx) # Note -dy to flip Y axis for standard cartesian
        angle_deg = math.degrees(angle_rad)
        
        if angle_deg < 0:
            angle_deg += 360
            
        # Standard compass sectors (Assuming Up is North)
        # North: 90, East: 0, West: 180, South: 270
        # Re-mapping to standard compass (0=N, 90=E, 180=S, 270=W)
        # Image Angle: 0=E, 90=N, 180=W, 270=S (-90)
        
        # Let's visualize standard unit circle:
        #      90 (N)
        # 180(W)   0(E)
        #     270 (S)
        
        if 67.5 <= angle_deg < 112.5: return "North"
        if 112.5 <= angle_deg < 157.5: return "North-West"
        if 157.5 <= angle_deg < 202.5: return "West"
        if 202.5 <= angle_deg < 247.5: return "South-West"
        if 247.5 <= angle_deg < 292.5: return "South"
        if 292.5 <= angle_deg < 337.5: return "South-East"
        if angle_deg >= 337.5 or angle_deg < 22.5: return "East"
        if 22.5 <= angle_deg < 67.5: return "North-East"
        
        return "Unknown"



