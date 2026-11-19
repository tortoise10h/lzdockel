;;; lzdockel-inspect.el --- Item inspect viewer for lzdockel  -*- lexical-binding: t; -*-

;;; Code:

(require 'json)
(require 'lzdockel-core)

(defvar-local lzdockel-inspect--kind nil
  "Docker kind (e.g. \"container\") of the item in the current inspect buffer.")

(defvar-local lzdockel-inspect--target nil
  "Docker name or ID inspected in the current inspect buffer.")

(defun lzdockel-inspect--item-name (kind item)
  "Return the display name of ITEM of KIND.
Falls back to the item ID when no name is available."
  (cond
   ((string= kind "image")
    (let ((repository (lzdockel-core-get item 'Repository)))
      (if (string-empty-p repository)
          (lzdockel-core-get item 'ID)
        (format "%s:%s" repository (lzdockel-core-get item 'Tag)))))
   ((string= kind "container")
    (let ((name (lzdockel-core-get item 'Names)))
      (if (string-empty-p name) (lzdockel-core-get item 'ID) name)))
   (t
    (let ((name (lzdockel-core-get item 'Name)))
      (if (string-empty-p name) (lzdockel-core-get item 'ID) name)))))

(defun lzdockel-inspect-buffer-name (kind name)
  "Return the inspect buffer name for a KIND item named NAME."
  (format "*lzdockel-inspect: %s %s*" kind name))

(defun lzdockel-inspect--fetch ()
  "Fetch `docker inspect' output for the current inspect buffer.
The buffer contents are replaced with the formatted JSON output
when the command finishes."
  (let ((buf (current-buffer))
        (kind lzdockel-inspect--kind)
        (target lzdockel-inspect--target))
    (lzdockel-core-run
     (lambda (output)
       (when (buffer-live-p buf)
         (with-current-buffer buf
           (let ((inhibit-read-only t))
             (erase-buffer)
             (insert output)
             (goto-char (point-min))
             (ignore-errors (json-pretty-print-buffer))))))
     kind "inspect" target)))

(defun lzdockel-inspect-refresh ()
  "Refresh the inspect output in the current `lzdockel-inspect-mode' buffer."
  (interactive)
  (when (derived-mode-p 'lzdockel-inspect-mode)
    (lzdockel-inspect--fetch)))

(defvar lzdockel-inspect-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'lzdockel-inspect-refresh)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `lzdockel-inspect-mode'.")

(define-derived-mode lzdockel-inspect-mode special-mode "Lzdockel-Inspect"
  "Major mode for viewing Docker inspect output."
  (setq buffer-read-only t)
  (setq-local revert-buffer-function
              (lambda (_ignore-auto _noconfirm)
                (lzdockel-inspect-refresh))))

(defun lzdockel-inspect-show (kind item)
  "Open an inspect buffer for ITEM of KIND and fetch its inspect output.
KIND is the docker object kind (e.g. \"container\", \"image\",
\"volume\" or \"network\").  Runs `docker KIND inspect' and shows
the output as formatted JSON.  The buffer is reused if it is
already open, and refreshed in that case."
  (let* ((name (lzdockel-inspect--item-name kind item))
         (id (lzdockel-core-get item 'ID))
         (buf (get-buffer-create (lzdockel-inspect-buffer-name kind name))))
    (with-current-buffer buf
      (unless (derived-mode-p 'lzdockel-inspect-mode)
        (lzdockel-inspect-mode))
      (setq lzdockel-inspect--kind kind)
      (setq lzdockel-inspect--target (if (string-empty-p id) name id))
      (setq header-line-format (format " Inspect: %s %s" kind name))
      (lzdockel-inspect--fetch))
    (pop-to-buffer buf)
    buf))

(provide 'lzdockel-inspect)
;;; lzdockel-inspect.el ends here
