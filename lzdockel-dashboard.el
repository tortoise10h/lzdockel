;;; lzdockel-dashboard.el --- Unified dashboard view  -*- lexical-binding: t; -*-

;;; Code:

(require 'lzdockel-core)
(require 'lzdockel-container)
(require 'lzdockel-image)
(require 'lzdockel-volume)
(require 'lzdockel-network)
(require 'lzdockel-faces)

(defvar lzdockel-dashboard-sections
  '(("Containers" . lzdockel-container)
    ("Images" . lzdockel-image)
    ("Volumes" . lzdockel-volume)
    ("Networks" . lzdockel-network))
  "List of dashboard sections as (TITLE . MODULE) pairs.")

(defvar lzdockel-dashboard-current-section 0
  "Index of the currently focused section.")

(defvar lzdockel-dashboard-data nil
  "Alist storing data for each section: (SECTION-INDEX . DATA-LIST).")

(defvar lzdockel-dashboard-section-bounds nil
  "Alist storing buffer positions for each section: (SECTION-INDEX . (START . END)).")

(defvar lzdockel-dashboard-item-keymap-entries
  '((?d . (("Containers" . lzdockel-container-delete)
           ("Images"     . lzdockel-image-delete)
           ("Volumes"    . lzdockel-volume-delete)
           ("Networks"   . lzdockel-network-delete)))
    (?r . (("Containers" . lzdockel-container-restart)))
    (?s . (("Containers" . lzdockel-container-stop))))
  "Dispatch table mapping keys to section-specific action functions.")

(defun lzdockel-dashboard-dispatch-action (key)
  "Execute the action bound to KEY for the item and section at point."
  (let* ((item (lzdockel-dashboard--item-at-point))
         (section-name (lzdockel-dashboard--section-name-at-point))
         (entries (cdr (assoc key lzdockel-dashboard-item-keymap-entries)))
         (action-fn (and section-name
                         (cdr (assoc section-name entries)))))
    (when (and item action-fn)
      (funcall action-fn item #'lzdockel-dashboard-refresh))))

(defvar lzdockel-dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'lzdockel-dashboard-next-section)
    (define-key map (kbd "<backtab>") #'lzdockel-dashboard-prev-section)
    (define-key map (kbd "S-<tab>") #'lzdockel-dashboard-prev-section)
    (define-key map (kbd "g") #'lzdockel-dashboard-refresh)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "d") (lambda () (interactive) (lzdockel-dashboard-dispatch-action ?d)))
    (define-key map (kbd "r") (lambda () (interactive) (lzdockel-dashboard-dispatch-action ?r)))
    (define-key map (kbd "s") (lambda () (interactive) (lzdockel-dashboard-dispatch-action ?s)))
    map)
  "Keymap for `lzdockel-dashboard-mode'.")

(defvar-local lzdockel-dashboard--override-active nil
  "Non-nil in dashboard buffers to activate the override keymap.
This ensures lzdockel keybindings take priority over modal editors
like evil, meow, etc. via `emulation-mode-map-alists'.")

(add-to-list 'emulation-mode-map-alists
             '((lzdockel-dashboard-mode-map . lzdockel-dashboard--override-active)))

(defface lzdockel-dashboard-section-header
  '((t :inherit font-lock-function-name-face :weight bold))
  "Face for section headers in the dashboard.")

(defface lzdockel-dashboard-section-active
  '((t :background "#3d5226" :weight bold))
  "Face for the active section header.")

(defface lzdockel-dashboard-item-selected
  '((t :background "#444444"))
  "Face for the selected item in a section.")

(defface lzdockel-dashboard-column-header
  '((t :inherit font-lock-comment-face :weight bold))
  "Face for column headers in sections.")

(defvar lzdockel-dashboard-column-headers
  '(("Containers" . "  %-12s %-30s %-20s %s")
    ("Images" . "  %-12s %-30s %-15s %s")
    ("Volumes" . "  %-15s %s")
    ("Networks" . "  %-12s %-25s %-15s %s"))
  "Format strings for column headers per section.")

(defvar lzdockel-dashboard-column-labels
  '(("Containers" . ["ID" "Image" "Created" "Name"])
    ("Images" . ["ID" "Repository" "Tag" "Size"])
    ("Volumes" . ["Driver" "Name"])
    ("Networks" . ["ID" "Name" "Driver" "Scope"]))
  "Column labels for each section.")

(define-derived-mode lzdockel-dashboard-mode special-mode "Lzdockel-Dashboard"
  "Major mode for the lzdockel unified dashboard."
  (setq buffer-read-only t)
  (hl-line-mode 1)
  (setq-local lzdockel-dashboard-current-section 0)
  (setq-local lzdockel-dashboard-data nil)
  (setq-local lzdockel-dashboard-section-bounds nil)
  (setq-local lzdockel-dashboard--override-active t))

(defun lzdockel-dashboard--section-header (title index)
  "Return a formatted section header string for TITLE at INDEX."
  (let* ((active (= index lzdockel-dashboard-current-section))
         (face (if active 'lzdockel-dashboard-section-active 'lzdockel-dashboard-section-header))
         (marker (if active "▸ " "  ")))
    (concat (propertize (format "%s[%d]-%s" marker (1+ index) title) 'face face) "\n")))

(defun lzdockel-dashboard--column-header (section-name)
  "Return a formatted column header string for SECTION-NAME."
  (let* ((labels (cdr (assoc section-name lzdockel-dashboard-column-labels)))
         (fmt (cdr (assoc section-name lzdockel-dashboard-column-headers))))
    (if (and labels fmt)
        (concat (propertize (apply #'format fmt (append labels nil)) 'face 'lzdockel-dashboard-column-header) "\n")
      "")))



(defun lzdockel-dashboard--container-active-p (container)
  "Return non-nil if CONTAINER is active (running)."
  (string-prefix-p "Up" (lzdockel-core-get container 'Status)))

(defun lzdockel-dashboard--sort-containers (containers)
  "Sort CONTAINERS so active ones appear first."
  (sort (copy-sequence containers)
        (lambda (a b)
          (and (lzdockel-dashboard--container-active-p a)
               (not (lzdockel-dashboard--container-active-p b))))))

(defun lzdockel-dashboard--format-container (container)
  "Format a CONTAINER alist for display."
  (let* ((id (lzdockel-core-get container 'ID))
         (short-id (substring id 0 (min 12 (length id))))
         (image (lzdockel-core-get container 'Image))
         (created (lzdockel-core-get container 'RunningFor))
         (status (lzdockel-core-get container 'Status))
         (names (lzdockel-core-get container 'Names))
         (exited (string-prefix-p "Exited" status))
         (status-face (cond
                        ((string-prefix-p "Up" status) 'lzdockel-status-running)
                        ((string-prefix-p "Exited" status) 'lzdockel-status-exited)
                        (t nil)))
         (line (format "  %-12s %-30s %-20s %s"
                       (propertize short-id 'face 'lzdockel-image-id)
                       image
                       created
                       names)))
    (when exited
      (setq line (propertize line 'face 'lzdockel-dashboard-item-dim)))
    (concat line
            " "
            (if status-face (propertize status 'face status-face) ""))))

(defun lzdockel-dashboard--format-image (image)
  "Format an IMAGE alist for display."
  (let* ((id (lzdockel-core-get image 'ID))
         (short-id (substring id 0 (min 12 (length id))))
         (repository (lzdockel-core-get image 'Repository))
         (tag (lzdockel-core-get image 'Tag))
         (size (lzdockel-core-get image 'Size)))
    (format "  %-12s %-30s %-15s %s"
            (propertize short-id 'face 'lzdockel-image-id)
            repository
            tag
            size)))

(defun lzdockel-dashboard--format-volume (volume)
  "Format a VOLUME alist for display."
  (let ((driver (lzdockel-core-get volume 'Driver))
        (name (lzdockel-core-get volume 'Name)))
    (format "  %-15s %s" driver name)))

(defun lzdockel-dashboard--format-network (network)
  "Format a NETWORK alist for display."
  (let* ((id (lzdockel-core-get network 'ID))
         (short-id (substring id 0 (min 12 (length id))))
         (name (lzdockel-core-get network 'Name))
         (driver (lzdockel-core-get network 'Driver))
         (scope (lzdockel-core-get network 'Scope)))
    (format "  %-12s %-25s %-15s %s"
            (propertize short-id 'face 'lzdockel-image-id)
            name
            driver
            scope)))

(defun lzdockel-dashboard--format-item (item section-index)
  "Format ITEM for display based on SECTION-INDEX."
  (let ((section-name (car (nth section-index lzdockel-dashboard-sections))))
    (cond
     ((string= section-name "Containers") (lzdockel-dashboard--format-container item))
     ((string= section-name "Images") (lzdockel-dashboard--format-image item))
     ((string= section-name "Volumes") (lzdockel-dashboard--format-volume item))
     ((string= section-name "Networks") (lzdockel-dashboard--format-network item))
     (t (format "  %s" item)))))

(defun lzdockel-dashboard--render-section (title index data)
  "Render a section with TITLE, INDEX, and DATA items."
  (let ((start (point)))
    (insert (lzdockel-dashboard--section-header title index))
    (insert (lzdockel-dashboard--column-header title))
    (if (null data)
        (insert "  (empty)\n")
      (dolist (item data)
        (let ((p (point)))
          (insert (lzdockel-dashboard--format-item item index) "\n")
          (add-text-properties p (1- (point))
                               (list 'lzdockel-item item
                                     'lzdockel-section title)))))
    (insert "\n")
    (cons index (cons start (point)))))

(defun lzdockel-dashboard--ascii-art ()
  "Return lzdockel title with theme-aware styling."
  (propertize "LZDockel" 'face 'lzdockel-dashboard-title))

(defun lzdockel-dashboard-render ()
  "Render the full dashboard with all sections."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert (lzdockel-dashboard--ascii-art) "\n\n")
    ;; (insert (make-string 50 ?═) "\n\n")
    (setq lzdockel-dashboard-section-bounds nil)
    (dotimes (i (length lzdockel-dashboard-sections))
      (let* ((section (nth i lzdockel-dashboard-sections))
             (title (car section))
             (data (cdr (assoc i lzdockel-dashboard-data))))
        (push (lzdockel-dashboard--render-section title i (or data '()))
              lzdockel-dashboard-section-bounds)))
    (setq lzdockel-dashboard-section-bounds (nreverse lzdockel-dashboard-section-bounds))
    (goto-char (point-min))))

(defun lzdockel-dashboard-fetch-all ()
  "Fetch data for all sections and render the dashboard."
  (let ((pending (length lzdockel-dashboard-sections))
        (results '()))
    (dotimes (i (length lzdockel-dashboard-sections))
      (let ((section-idx i)
            (module (cdr (nth i lzdockel-dashboard-sections))))
          (let ((fetch-fn (intern (format "%s-list" (symbol-name module)))))
          (funcall fetch-fn
                   (lambda (data)
                     (when (eq section-idx 0)
                       (setq data (lzdockel-dashboard--sort-containers data)))
                     (push (cons section-idx data) results)
                     (setq pending (1- pending))
                     (when (zerop pending)
                       (when (buffer-live-p (get-buffer "*lzdockel-dashboard*"))
                         (with-current-buffer "*lzdockel-dashboard*"
                           (setq lzdockel-dashboard-data (nreverse results))
                           (lzdockel-dashboard-render)))))))))))

(defun lzdockel-dashboard-refresh ()
  "Refresh all dashboard data."
  (interactive)
  (lzdockel-dashboard-fetch-all))

(defun lzdockel-dashboard-next-section ()
  "Move to the next section."
  (interactive)
  (let ((count (length lzdockel-dashboard-sections)))
    (setq lzdockel-dashboard-current-section
          (mod (1+ lzdockel-dashboard-current-section) count)))
  (lzdockel-dashboard-render)
  (lzdockel-dashboard-goto-section lzdockel-dashboard-current-section))

(defun lzdockel-dashboard-prev-section ()
  "Move to the previous section."
  (interactive)
  (let ((count (length lzdockel-dashboard-sections)))
    (setq lzdockel-dashboard-current-section
          (mod (1- lzdockel-dashboard-current-section) count)))
  (lzdockel-dashboard-render)
  (lzdockel-dashboard-goto-section lzdockel-dashboard-current-section))

(defun lzdockel-dashboard-goto-section (index)
  "Move point to the first item of section at INDEX."
  (let ((bounds (cdr (assoc index lzdockel-dashboard-section-bounds))))
    (when bounds
      (let ((first-item-pos (lzdockel-dashboard--first-item-pos bounds)))
        (if first-item-pos
            (goto-char first-item-pos)
          (goto-char (car bounds)))))))

(defun lzdockel-dashboard--first-item-pos (bounds)
  "Return buffer position of the first item line within BOUNDS (section-start . section-end).
Returns nil if section has no items (e.g. empty)."
  (save-excursion
    (goto-char (car bounds))
    (forward-line 2)
    (when (< (point) (cdr bounds))
      (point))))


(defun lzdockel-dashboard--text-property-at-point (prop)
  "Return text property PROP at point, falling back to line start.
Covers point-at-EOL and other positions where the property is at
line-beginning-position."
  (or (get-text-property (point) prop)
      (get-text-property (line-beginning-position) prop)))

(defun lzdockel-dashboard--item-at-point ()
  "Return the item alist for the item line at point, or nil."
  (lzdockel-dashboard--text-property-at-point 'lzdockel-item))

(defun lzdockel-dashboard--section-name-at-point ()
  "Return the section title string for the line at point, or nil."
  (lzdockel-dashboard--text-property-at-point 'lzdockel-section))

(defun lzdockel-dashboard-get-selected-item ()
  "Return the item alist at point, or nil if not on an item line."
  (lzdockel-dashboard--item-at-point))

;;;###autoload
(defun lzdockel-dashboard ()
  "Open the lzdockel unified dashboard."
  (interactive)
  (let ((buf (get-buffer-create "*lzdockel-dashboard*")))
    (switch-to-buffer buf)
    (lzdockel-dashboard-mode)
    (lzdockel-dashboard-fetch-all)))

(provide 'lzdockel-dashboard)
;;; lzdockel-dashboard.el ends here
