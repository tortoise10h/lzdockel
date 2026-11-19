;;; lzdockel-image.el --- Image list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'lzdockel-core)
(require 'lzdockel-inspect)

(defun lzdockel-image-list (callback)
  "Fetch Docker images asynchronously, calling CALLBACK with results.
CALLBACK receives a list of image alists."
  (lzdockel-core-run
   (lambda (output)
     (funcall callback (lzdockel-core-parse-json-lines output)))
   "image" "ls" "--format" "{{json .}}"))

(defun lzdockel-image-delete (item callback)
  "Delete the image referenced by ITEM, with confirmation.
CALLBACK is called on success."
  (lzdockel-core-action-run
   (format "Delete image %s:%s? "
           (lzdockel-core-get item 'Repository)
           (lzdockel-core-get item 'Tag))
   `("image" "rm" ,(lzdockel-core-get item 'ID))
   callback))

(defun lzdockel-image-inspect (item &optional _callback)
  "Open an inspect buffer for the image referenced by ITEM.
CALLBACK is accepted for `lzdockel-dashboard-dispatch-action'
compatibility and ignored."
  (lzdockel-inspect-show "image" item))

(provide 'lzdockel-image)
;;; lzdockel-image.el ends here
