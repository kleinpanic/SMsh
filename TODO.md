# TODO / Future Improvements

Below is a list of planned advancements and enhancements for SMsh.sh:

1. **Enhanced Logging:**  
   - Implement a logging mechanism with multiple verbosity levels.
   - Option to log to a file.

2. **Improved Error Handling:**  
   - Adopt `set -euo pipefail` for better error detection.
   - Enhance error messages and exit status reporting.

3. **Configuration File Support:**  
   - Allow users to specify a config file to set default values for messages, subjects, carriers, etc.

4. **Extended Phone Number Validation:**  
   - Update validation to support international phone formats.
   - Allow flexible input formats (e.g., with dashes, spaces, or country codes).

5. **Carrier Selection:**  
   - Provide an interactive menu or command-line option to select a specific carrier.
   - Consider auto-detection based on phone number patterns.

6. **Concurrency Control:**  
   - Explore advanced job management (e.g., using semaphores or named pipes) for better concurrency handling.

7. **Additional Command-Line Options:**  
   - Add verbose/debug and version flags.
   - Enhance help/usage information.

8. **Improved Cleanup:**  
   - Refine the child process cleanup mechanism to target only spawned processes.

9. **User Feedback:**  
   - Add a progress indicator and summary report for sent/failed messages.

10. **Modular Code Refactoring:**  
    - Break the script into modular functions or separate files for better maintainability.

11. **Internationalization/Localization:**  
    - Support multiple languages for user prompts and messages.

12. **Input Sanitization:**  
    - Enhance sanitization for both file and interactive inputs.

Feel free to contribute or open issues for any additional ideas or enhancements.

