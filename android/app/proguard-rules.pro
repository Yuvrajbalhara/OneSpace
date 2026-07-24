# OneSpace uses only TextRecognitionScript.latin. The Flutter ML Kit wrapper
# references the optional language recognizers at runtime, but those artifacts
# are intentionally not included in this build.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
