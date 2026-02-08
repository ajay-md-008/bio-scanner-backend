import cv2
from vision_engine import OilDropAnalyzer
import sys

def main():
    if len(sys.argv) < 2:
        print("Usage: python test_engine_local.py <path_to_video>")
        return

    video_path = sys.argv[1]
    print(f"Analyzing {video_path}...")

    analyzer = OilDropAnalyzer()
    
    # Run analysis
    results = analyzer.analyze_video(video_path)
    
    if "error" in results:
        print(f"Error: {results['error']}")
    else:
        print("\nanalysis Results:")
        print("-" * 30)
        print(f"Speed: {results['speed']} pixels/sec (approx)")
        print(f"Direction: {results['direction']}")
        print(f"Final Shape: {results['shape']}")
        print(f"Duration: {results['duration_sec']} sec")
        print("-" * 30)

if __name__ == "__main__":
    main()
