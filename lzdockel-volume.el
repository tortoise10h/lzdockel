;;; lzdockel-volume.el --- Volume list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'lzdockel-core)
(require 'lzdockel-inspect)

(defun lzdockel-volume-list (callback)
  "Fetch Docker volumes asynchronously, calling CALLBACK with results.
CALLBACK receives a list of volume alists."
  (lzdockel-core-run
   (lambda (output)
     (funcall callback (lzdockel-core-parse-json-lines output)))
   "volume" "ls" "--format" "{{json .}}"))

(defun lzdockel-volume-delete (item callback)
  "Delete the volume referenced by ITEM, with confirmation.
CALLBACK is called on success."
  (lzdockel-core-action-run
   (format "Delete volume %s? " (lzdockel-core-get item 'Name))
   `("volume" "rm" ,(lzdockel-core-get item 'Name))
   callback))

(defun lzdockel-volume-inspect (item &optional _callback)
  "Open an inspect buffer for the volume referenced by ITEM.
CALLBACK is accepted for `lzdockel-dashboard-dispatch-action'
compatibility and ignored."
  (lzdockel-inspect-show "volume" item))

(provide 'lzdockel-volume)
;;; lzdockel-volume.el ends here
