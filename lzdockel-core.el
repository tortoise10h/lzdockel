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

(defun lzdockel-core-run-sync (&rest args)
  "Run docker with ARGS synchronously, return stdout as a string."
  (let ((result (apply #'call-process "docker" nil t nil args)))
    (if (zerop result)
        (buffer-string)
      (error "docker %s failed with exit code %s" (mapconcat #'identity args " ") result))))

(provide 'lzdockel-core)
;;; lzdockel-core.el ends here
