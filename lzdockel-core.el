;;; lzdockel-core.el --- Core infrastructure for lzdockel  -*- lexical-binding: t; -*-

;;; Code:

(require 'json)

(defun lzdockel-core-parse-json-lines (output)
  "Parse newline-delimited JSON OUTPUT into a list of alists.
Each line in OUTPUT is expected to be a valid JSON object."
  (let ((lines (split-string output "\n" t))
        (results '()))
    (dolist (line lines results)
      (condition-case nil
          (push (json-parse-string line :object-type 'alist) results)
        (json-parse-error
         (message "lzdockel: failed to parse JSON line: %s" line))))))

(defun lzdockel-core-run (callback &rest args)
  "Run docker with ARGS asynchronously, calling CALLBACK with output on success.
CALLBACK is called with one argument: the stdout output as a string."
  (let ((process-connection-type nil)
        (buffer (generate-new-buffer " *lzdockel-docker*")))
    (make-process
     :name "lzdockel-docker"
     :buffer buffer
     :command (append '("docker") args)
     :sentinel (lambda (proc event)
                 (when (string-match-p "finished" event)
                   (let ((output (with-current-buffer (process-buffer proc)
                                   (buffer-string))))
                     (funcall callback output)))
                 (kill-buffer (process-buffer proc))))))

(defun lzdockel-core-run-action (callback &rest args)
  "Run docker with ARGS asynchronously for side-effect commands.
CALLBACK is called with (SUCCESS-P . MESSAGE) when the process finishes.
SUCCESS-P is non-nil if the process exited successfully.
MESSAGE is the stderr output on failure or a success string."
  (let ((process-connection-type nil)
        (buffer (generate-new-buffer " *lzdockel-docker-action*"))
        (err-buffer (generate-new-buffer " *lzdockel-docker-err*")))
    (make-process
     :name "lzdockel-docker-action"
     :buffer buffer
     :command (append '("docker") args)
     :stderr err-buffer
     :sentinel (lambda (proc event)
                 (when (string-match-p "\\(finished\\|exited\\)" event)
                   (let ((exit-code (process-exit-status proc))
                         (stderr (with-current-buffer err-buffer
                                   (string-trim (buffer-string))))
                         (success-p (= 0 (process-exit-status proc))))
                     (funcall callback
                              (cons success-p
                                    (if success-p
                                        "Action completed successfully"
                                      (format "Command failed (exit %d): %s" exit-code stderr))))
                     (kill-buffer (process-buffer proc))
                     (kill-buffer err-buffer)))))))

(provide 'lzdockel-core)
;;; lzdockel-core.el ends here
