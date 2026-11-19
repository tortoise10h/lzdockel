;;; lzdockel-container.el --- Container list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'eshell)
(require 'esh-mode)
(require 'lzdockel-core)
(require 'lzdockel-logs)
(require 'lzdockel-inspect)

(defun lzdockel-container-list (callback)
  "Fetch Docker containers asynchronously, calling CALLBACK with results.
CALLBACK receives a list of container alists."
  (lzdockel-core-run
   (lambda (output)
     (funcall callback (lzdockel-core-parse-json-lines output)))
   "container" "ls" "-a" "--format" "{{json .}}"))

(defun lzdockel-container-delete (item callback)
  "Delete the container referenced by ITEM, with confirmation.
CALLBACK is called on success."
  (lzdockel-core-action-run
   (format "Delete container %s? " (lzdockel-core-get item 'Names))
   `("container" "rm" ,(lzdockel-core-get item 'ID))
   callback))

(defun lzdockel-container-restart (item callback)
  "Restart the container referenced by ITEM, with confirmation.
CALLBACK is called on success."
  (lzdockel-core-action-run
   (format "Restart container %s? " (lzdockel-core-get item 'Names))
   `("container" "restart" ,(lzdockel-core-get item 'ID))
   callback))

(defun lzdockel-container-stop (item callback)
  "Stop the container referenced by ITEM, with confirmation.
CALLBACK is called on success."
  (lzdockel-core-action-run
   (format "Stop container %s? " (lzdockel-core-get item 'Names))
   `("container" "stop" ,(lzdockel-core-get item 'ID))
   callback))

(defun lzdockel-container-logs (item)
  "Open a logs buffer for the container referenced by ITEM."
  (lzdockel-logs-show item))

(defun lzdockel-container-inspect (item &optional _callback)
  "Open an inspect buffer for the container referenced by ITEM.
CALLBACK is accepted for `lzdockel-dashboard-dispatch-action'
compatibility and ignored."
  (lzdockel-inspect-show "container" item))

(defun lzdockel-container-attach-buffer-name (item)
  "Return the attach eshell buffer name for container ITEM."
  (let ((name (lzdockel-core-get item 'Names))
        (id (lzdockel-core-get item 'ID)))
    (format "*lzdockel-attach: %s*"
            (if (string-empty-p name) id name))))

(defun lzdockel-container-attach (item &optional _callback)
  "Attach to the container referenced by ITEM in a separate eshell buffer.
Runs `docker exec -it CONTAINER /bin/sh' in an eshell buffer named
after the container, reusing the buffer if it is already open.
Prompts for confirmation before opening a new attach buffer.
CALLBACK is accepted for `lzdockel-dashboard-dispatch-action'
compatibility and ignored."
  (let* ((id (lzdockel-core-get item 'ID))
         (name (lzdockel-core-get item 'Names))
         (target (if (string-empty-p id) name id))
         (bufname (lzdockel-container-attach-buffer-name item))
         (buf (get-buffer bufname)))
    (cond
     (buf (pop-to-buffer buf))
     ((yes-or-no-p (format "Attach to container %s? " name))
      (let ((eshell-buffer-name bufname))
        (eshell)
        (insert (format "docker exec -it %s /bin/sh" target))
        (eshell-send-input))))))

(provide 'lzdockel-container)
;;; lzdockel-container.el ends here
