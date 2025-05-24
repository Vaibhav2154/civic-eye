import cv2
import numpy as np
import os
from PIL import Image, ImageChops
import matplotlib.pyplot as plt
from sklearn.cluster import DBSCAN
import tempfile
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ImageForensicsAnalyzer:
    """
    A comprehensive class to detect various types of image tampering
    """
    
    def __init__(self, temp_dir=None):
        """Initialize the detector with optional temp directory for intermediate files"""
        self.temp_dir = temp_dir or tempfile.gettempdir()
        
    def validate_image(self, file_path):
        """
        Main validation function that combines multiple detection methods
        Returns: 
            - True if the image appears authentic
            - False if tampering is detected
            - Dictionary with detailed results for each test
        """
        results = {
            "is_authentic": True,
            "tests": {}
        }
        
        # Run all detection methods
        # results["tests"]["copy_move"] = not self.detect_copy_move(file_path)
        # results["tests"]["ela"] = not self.detect_ela(file_path)
        results["tests"]["noise_variance"] = not self.detect_noise_inconsistency(file_path)
        results["tests"]["double_jpeg"] = not self.detect_double_jpeg_compression(file_path)
        
        # If any test detects tampering, mark the image as not authentic
        if not all(results["tests"].values()):
            results["is_authentic"] = False
        
        return results["is_authentic"], results
    
    def detect_copy_move(self, file_path, eps=60, min_samples=2):
        """
        Detect copy-move forgery using SIFT features and DBSCAN clustering
        
        Returns:
            - True if copy-move forgery is detected
            - False otherwise
        """
        try:
            # Read the image
            image = cv2.imread(file_path)
            if image is None:
                return False
                
            # Convert to grayscale
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            
            # SIFT feature extraction
            sift = cv2.SIFT_create()
            key_points, descriptors = sift.detectAndCompute(gray, None)
            
            # Check if we have enough key points
            # if descriptors is None or len(key_points) < min_samples * 2:
            #     return False
                
            # DBSCAN clustering to find similar regions
            clusters = DBSCAN(eps=eps, min_samples=min_samples).fit(descriptors)
            
            # Count regions with duplicate features
            labels = clusters.labels_
            unique_labels = set(labels) - {-1}  # Exclude noise points
            
            # Create a copy of the image for visualization
            result_img = image.copy()
            
            # Count potential forgery regions
            forgery_count = 0
            for label in unique_labels:
                # Get points in this cluster
                cluster_indices = np.where(labels == label)[0]
                
                # If cluster has enough points, it's a potential forgery
                if len(cluster_indices) >= min_samples * 2:
                    forgery_count += 1
                    
                    # Mark the keypoints for visualization
                    cluster_points = [key_points[i] for i in cluster_indices]
                    result_img = cv2.drawKeypoints(result_img, cluster_points, None, 
                                          color=(0, 0, 255), flags=cv2.DRAW_MATCHES_FLAGS_DRAW_RICH_KEYPOINTS)
            
            # Save the result image for debugging/display
            output_path = os.path.join(self.temp_dir, "copy_move_result.jpg")
            cv2.imwrite(output_path, result_img)
            
            # If we have multiple similar regions, it's likely a copy-move forgery
            return forgery_count > 0
            
        except Exception as e:
            print(f"Copy-move detection error: {e}")
            return False
    
    def detect_ela(self, file_path, quality=90, scale=10):
        """
        Perform Error Level Analysis to detect potential image manipulation
        
        Returns:
            - True if suspicious ELA pattern is detected
            - False otherwise
        """
        try:
            # Set up temporary file paths
            temp_jpg = os.path.join(self.temp_dir, "ela_temp.jpg")
            ela_output = os.path.join(self.temp_dir, "ela_result.jpg")
            
            # Open original image
            original = Image.open(file_path)
            
            # Save with specified JPEG quality
            original.save(temp_jpg, quality=quality)
            
            # Open the saved JPEG
            resaved = Image.open(temp_jpg)
            
            # Calculate the difference
            diff = ImageChops.difference(original, resaved)
            
            # Amplify the difference
            diff_array = np.array(diff)
            amplified_diff = np.minimum(diff_array * scale, 255).astype(np.uint8)
            ela_image = Image.fromarray(amplified_diff)
            
            # Save the ELA result
            ela_image.save(ela_output)
            
            # Analyze the ELA image for inconsistencies
            diff_stats = np.array(ela_image).sum(axis=2)
            
            # Calculate standard deviation of error levels
            std_dev = np.std(diff_stats)
            
            # Calculate the percentage of high-error pixels
            high_error_threshold = np.percentile(diff_stats, 95)
            high_error_pixels = np.sum(diff_stats > high_error_threshold)
            high_error_percentage = high_error_pixels / diff_stats.size
            
            # If standard deviation is high or there are concentrated high-error regions,
            # this may indicate tampering
            return std_dev > 15 or high_error_percentage > 0.01
            
        except Exception as e:
            print(f"ELA detection error: {e}")
            return False
    
    def detect_noise_inconsistency(self, file_path, block_size=16):
        """
        Detect noise variance inconsistency in image blocks
        
        Returns:
            - True if inconsistent noise patterns are detected
            - False otherwise
        """
        try:
            # Read the image
            image = cv2.imread(file_path)
            if image is None:
                return False
                
            # Convert to grayscale
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            
            # Get image dimensions
            height, width = gray.shape
            
            # Prepare to collect noise variance for blocks
            noise_variance = []
            
            # Process image in blocks
            for y in range(0, height - block_size, block_size):
                for x in range(0, width - block_size, block_size):
                    # Extract block
                    block = gray[y:y+block_size, x:x+block_size]
                    
                    # Apply median filter to estimate noise-free block
                    denoised = cv2.medianBlur(block, 3)
                    
                    # Calculate noise as difference between original and denoised
                    noise = block.astype(np.float32) - denoised.astype(np.float32)
                    
                    # Calculate variance of noise
                    var = np.var(noise)
                    noise_variance.append(var)
            
            # Convert to numpy array for analysis
            noise_variance = np.array(noise_variance)
            
            # Calculate statistics of noise variance
            mean_variance = np.mean(noise_variance)
            std_variance = np.std(noise_variance)
            cv = std_variance / mean_variance if mean_variance > 0 else 0
            
            # Create a heatmap visualization of the noise variance
            heatmap = np.zeros((height // block_size, width // block_size))
            idx = 0
            for y in range(height // block_size):
                for x in range(width // block_size):
                    if idx < len(noise_variance):
                        heatmap[y, x] = noise_variance[idx]
                        idx += 1
            
            # Save the heatmap visualization
            plt.figure(figsize=(10, 8))
            plt.imshow(heatmap, cmap='hot')
            plt.colorbar(label='Noise Variance')
            plt.title('Noise Variance Map')
            plt.savefig(os.path.join(self.temp_dir, "noise_variance_map.jpg"))
            plt.close()
            
            # If the coefficient of variation is high, it indicates inconsistent noise
            # which could be a sign of tampering
            return cv > 5.0  # Threshold determined empirically
            
        except Exception as e:
            print(f"Noise inconsistency detection error: {e}")
            return False
    
    def detect_double_jpeg_compression(self, file_path):
        """
        Detect double JPEG compression which can indicate manipulation
        
        Returns:
            - True if double compression is detected
            - False otherwise
        """
        try:
            # Read the image
            image = cv2.imread(file_path, cv2.IMREAD_GRAYSCALE)
            if image is None:
                return False
                
            # DCT transform
            height, width = image.shape
            block_size = 8  # JPEG uses 8x8 blocks
            
            # Ensure image dimensions are multiples of block_size
            height = height - (height % block_size)
            width = width - (width % block_size)
            image = image[:height, :width]
            
            # Initialize histogram
            hist = np.zeros(256)
            
            # Process image in blocks
            for y in range(0, height, block_size):
                for x in range(0, width, block_size):
                    # Extract block
                    block = image[y:y+block_size, x:x+block_size].astype(np.float32)
                    
                    # Apply DCT
                    dct_block = cv2.dct(block)
                    
                    # Extract DCT coefficients and add to histogram
                    for i in range(block_size):
                        for j in range(block_size):
                            if i != 0 or j != 0:  # Skip DC coefficient
                                coef = int(dct_block[i, j]) + 128
                                if 0 <= coef <= 255:
                                    hist[coef] += 1
            
            # Normalize histogram
            hist = hist / np.sum(hist)
            
            # Calculate periodicity of histogram
            fft_hist = np.abs(np.fft.fft(hist))
            
            # Analyze the FFT for periodicity (peaks at certain frequencies)
            # Skip the DC component (index 0)
            periodic_strength = np.max(fft_hist[1:len(fft_hist)//2]) / np.mean(fft_hist[1:len(fft_hist)//2])
            
            # Save the histogram visualization
            plt.figure(figsize=(10, 6))
            plt.bar(range(256), hist)
            plt.title('DCT Coefficient Histogram')
            plt.xlabel('DCT Coefficient + 128')
            plt.ylabel('Normalized Frequency')
            plt.savefig(os.path.join(self.temp_dir, "dct_histogram.jpg"))
            plt.close()
            
            # If there's strong periodicity, it indicates double compression
            return periodic_strength > 2.5  # Threshold determined empirically
            
        except Exception as e:
            print(f"Double JPEG compression detection error: {e}")
            return False

# Function to use from external applications
def validate_image(file_path):
    """
    Validate if an image has been tampered with
    
    Args:
        file_path (str): Path to the image file
        
    Returns:
        tuple: (is_authentic, results_dict)
            - is_authentic: Boolean indicating if the image appears authentic
            - results_dict: Dictionary with detailed results for each test
    """
    analyzer = ImageForensicsAnalyzer()
    return analyzer.validate_image(file_path)

# For streamlit or web-based applications
async def validate_uploaded_image(file):
    """
    Validate an uploaded image file
    
    Args:
        file: Uploaded file object (from FastAPI or Streamlit)
        
    Returns:
        bool: True if the image appears authentic, False if tampering is detected
    """
    # Create a temporary file
    temp_file = tempfile.NamedTemporaryFile(delete=False)
    temp_path = temp_file.name
    
    try:
        # Reset the file cursor to the beginning
        await file.seek(0)
        
        # Read the file content
        content = await file.read()
        
        # Log file information for debugging
        logger.info(f"Processing uploaded file: {file.filename}, size: {len(content)} bytes")
        
        # Write the content to the temporary file
        with open(temp_path, "wb") as f:
            f.write(content)
        
        logger.info(f"Saved to temporary file: {temp_path}")
        
        # Validate the image
        is_authentic, results = validate_image(temp_path)
        
        # Log the validation results
        logger.info(f"Validation results: authentic={is_authentic}, details={results}")
        
        return is_authentic
    except Exception as e:
        logger.error(f"Error in validate_uploaded_image: {str(e)}")
        # Return False on any error (assume tampering)
        return False
    finally:
        # Clean up the temporary file
        try:
            os.unlink(temp_path)
        except Exception as e:
            logger.warning(f"Failed to delete temporary file: {str(e)}")

# Example usage
if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python validate_image.py <image_file>")
        sys.exit(1)
    
    image_path = sys.argv[1]
    is_authentic, results = validate_image(image_path)
    
    print(f"Image appears authentic: {is_authentic}")
    print("Detailed results:")
    for test, passed in results["tests"].items():
        print(f"  {test}: {'Passed' if passed else 'Failed'}")