import cv2
import numpy as np
import os
import joblib
from sklearn.model_selection import train_test_split
from sklearn.svm import SVC
from sklearn.neighbors import KNeighborsClassifier
from sklearn.metrics import classification_report, accuracy_score
import glob

# Configuration
DATASET_PATH = "dataset"
MODEL_PATH = "oil_shape_model.pkl"
LABEL_ENCODER_PATH = "label_encoder.pkl"

def extract_features(image_path):
    """
    Extracts shape features from an image.
    Features: Hu Moments (7), Solidity, Aspect Ratio, Circularity.
    Total Features: 10
    """
    img = cv2.imread(image_path)
    if img is None:
        return None

    # Preprocessing
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    
    # Thresholding (Otsu's)
    # Note: Adjust THRESH_BINARY vs THRESH_BINARY_INV based on image type (dark oil / light background)
    ret, thresh = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    
    # Find largest contour
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    if not contours:
        return None
        
    cnt = max(contours, key=cv2.contourArea)
    area = cv2.contourArea(cnt)
    
    if area < 50: # Ignore noise
        return None

    # Feature 1: Hu Moments (Shape descriptors invariant to scale/rotation)
    moments = cv2.moments(cnt)
    hu_moments = cv2.HuMoments(moments).flatten()
    # Log transform to make range manageable
    hu_moments = -np.sign(hu_moments) * np.log10(np.abs(hu_moments) + 1e-10)

    # Feature 2: Solidity
    hull = cv2.convexHull(cnt)
    hull_area = cv2.contourArea(hull)
    solidity = float(area) / hull_area if hull_area > 0 else 0

    # Feature 3: Aspect Ratio
    x, y, w, h = cv2.boundingRect(cnt)
    aspect_ratio = float(w) / h

    # Feature 4: Circularity
    perimeter = cv2.arcLength(cnt, True)
    circularity = (4 * np.pi * area) / (perimeter ** 2) if perimeter > 0 else 0

    # Combine features
    features = np.hstack([hu_moments, [solidity, aspect_ratio, circularity]])
    return features

def load_data():
    X = []
    y = []
    classes = [d for d in os.listdir(DATASET_PATH) if os.path.isdir(os.path.join(DATASET_PATH, d))]
    
    print(f"Found classes: {classes}")
    
    for label in classes:
        folder_path = os.path.join(DATASET_PATH, label)
        image_files = glob.glob(os.path.join(folder_path, "*.jpg")) + \
                      glob.glob(os.path.join(folder_path, "*.png")) + \
                      glob.glob(os.path.join(folder_path, "*.jpeg"))
        
        print(f"Processing {label}: {len(image_files)} images")
        
        for img_path in image_files:
            feats = extract_features(img_path)
            if feats is not None:
                X.append(feats)
                y.append(label)
            else:
                print(f"Skipping {img_path} (No contour found)")

    return np.array(X), np.array(y)

def train():
    print("Loading dataset...")
    X, y = load_data()
    
    if len(X) == 0:
        print("No valid images found in dataset/ folder.")
        print("Please add images to: dataset/snake, dataset/pearl, etc.")
        return

    # Split Data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Train Classifier (SVM is good for small features sets)
    print("Training SVM Classifier...")
    clf = SVC(kernel='linear', probability=True)
    clf.fit(X_train, y_train)
    
    # Evaluate
    if len(X_test) > 0:
        y_pred = clf.predict(X_test)
        print("\nEvaluation Results:")
        print(classification_report(y_test, y_pred))
        print(f"Accuracy: {accuracy_score(y_test, y_pred):.2f}")
    else:
        print("Not enough data for test set. Trained on all data.")

    # Save Model
    joblib.dump(clf, MODEL_PATH)
    print(f"Model saved to {MODEL_PATH}")

if __name__ == "__main__":
    train()
