;;; lzdockel-format.el --- Formatting helpers for lzdockel  -*- lexical-binding: t; -*-

;;; Code:

(defconst lzdockel-format--port-mapping-regexp
  "\\(?:[0-9.]+\\|\\[[^]]+\\]\\|::\\):\\([0-9]+\\(?:-[0-9]+\\)?\\)->\\([0-9]+\\(?:-[0-9]+\\)?\\)/\\(.*\\)"
  "Regexp matching a Docker host-to-container port mapping entry.
Group 1 is the host port (or range), group 2 is the container port,
and group 3 is the protocol.")

(defun lzdockel-format-host-ports (ports)
  "Extract unique open host ports from a Docker PORTS string.
Ignores container-only exposed ports without host bindings (no `->')
and deduplicates IPv4/IPv6 duplicates, preserving order."
  (if (or (null ports) (string-empty-p ports))
      nil
    (let ((entries (split-string ports ", *" t))
          (result '()))
      (dolist (entry entries)
        (when (string-match lzdockel-format--port-mapping-regexp entry)
          (let ((host-port (match-string 1 entry)))
            (unless (member host-port result)
              (push host-port result)))))
      (nreverse result))))

(defun lzdockel-format-ports (ports &optional max-width)
  "Simplify Docker PORTS string for compact display.
Extracts host-mapped ports and deduplicates IPv4/IPv6.
When MAX-WIDTH is a positive integer, truncate the result to fit
within MAX-WIDTH display columns using an ellipsis.  When MAX-WIDTH
is nil, return the full simplified port string."
  (if (or (null ports) (string-empty-p ports))
      ""
    (let* ((entries (split-string ports ", *" t))
           (mapped '())
           (exposed '())
           (seen '()))
      (dolist (entry entries)
        (cond
         ((string-match lzdockel-format--port-mapping-regexp entry)
          (let ((key (concat (match-string 1 entry) ":" (match-string 2 entry))))
            (unless (member key seen)
              (push key seen)
              (push (format "%s→%s" (match-string 1 entry) (match-string 2 entry)) mapped))))
         ((string-match "^\\([0-9]+\\(?:-[0-9]+\\)?\\)/" entry)
          (push (match-string 1 entry) exposed))))
      (let ((result (mapconcat #'identity (nreverse mapped) ", ")))
        (when exposed
          (when (> (length result) 0)
            (setq result (concat result ", ")))
          (setq result (concat result (mapconcat #'identity (nreverse exposed) ","))))
        (if (and (integerp max-width) (> max-width 0) (> (string-width result) max-width))
            (if (<= max-width 1)
                (truncate-string-to-width result max-width)
              (truncate-string-to-width result max-width nil nil "…"))
          result)))))

(provide 'lzdockel-format)
;;; lzdockel-format.el ends here
