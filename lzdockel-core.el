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

(defun lzdockel-core-get (alist key)
  "Get VALUE from ALIST by KEY, handling both string and symbol keys."
  (or (cdr (assoc key alist))
      (cdr (assoc (symbol-name key) alist))
      ""))

(defun lzdockel-core-action-run (confirm-prompt args &optional callback)
  "Run a docker action with confirmation.
CONFIRM-PROMPT is shown as a yes/no question. ARGS are passed to
docker. CALLBACK is called on success."
  (when (yes-or-no-p confirm-prompt)
    (apply #'lzdockel-core-run
           (lambda (_output)
             (when callback (funcall callback)))
           args)))

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

(defun lzdockel-core-check-docker (callback)
  "Check whether the Docker CLI and daemon are available.
Calls CALLBACK asynchronously (or immediately when CLI is missing)
with two arguments: (STATUS DETAIL).
STATUS is one of:
  `ok'          - Docker CLI exists and daemon is reachable.
  `missing-cli' - `docker' executable was not found on `exec-path'.
  `daemon-down' - `docker' executable exists, but daemon check failed.
DETAIL is a trimmed error string when available, or nil."
  (if (not (executable-find "docker"))
      (funcall callback 'missing-cli nil)
    (let ((process-connection-type nil)
          (buffer (generate-new-buffer " *lzdockel-docker-check*"))
          (err-buffer (generate-new-buffer " *lzdockel-docker-check-err*")))
      (condition-case err
          (make-process
           :name "lzdockel-docker-check"
           :buffer buffer
           :command '("docker" "info" "--format" "{{.ServerVersion}}")
           :stderr err-buffer
           :sentinel
           (lambda (proc _event)
             (when (memq (process-status proc) '(exit signal))
               (let* ((ok (and (eq (process-status proc) 'exit)
                               (zerop (process-exit-status proc))))
                      (stderr (when (buffer-live-p err-buffer)
                                (with-current-buffer err-buffer
                                  (string-trim (buffer-string)))))
                      (stdout (when (buffer-live-p buffer)
                                (with-current-buffer buffer
                                  (string-trim (buffer-string)))))
                      (detail (cond
                               ((and stderr (not (string-empty-p stderr))) stderr)
                               ((and stdout (not (string-empty-p stdout))) stdout)
                               (t nil))))
                 (when (buffer-live-p buffer) (kill-buffer buffer))
                 (when (buffer-live-p err-buffer) (kill-buffer err-buffer))
                 (if ok
                     (funcall callback 'ok nil)
                   (funcall callback 'daemon-down detail))))))
        (file-error
         (when (buffer-live-p buffer) (kill-buffer buffer))
         (when (buffer-live-p err-buffer) (kill-buffer err-buffer))
         (funcall callback 'missing-cli (error-message-string err)))))))

(provide 'lzdockel-core)
;;; lzdockel-core.el ends here
