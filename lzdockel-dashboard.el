;;; lzdockel-dashboard.el --- Unified dashboard view  -*- lexical-binding: t; -*-

;;; Code:

(require 'lzdockel-core)
(require 'lzdockel-format)
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

(defvar-local lzdockel-dashboard--error-state nil
  "Non-nil when displaying a Docker unavailable error screen.
Holds a plist (:reason SYMBOL :detail STRING-OR-NIL).")

(defvar-local lzdockel-dashboard--last-render-width nil
  "Display width in columns used during the most recent dashboard render.")

(defvar lzdockel-dashboard-default-width 100
  "Fallback display width in columns when the dashboard has no live window.")

(defconst lzdockel-dashboard--container-indent 2
  "Leading indentation width in columns for Containers table rows.")

(defconst lzdockel-dashboard--container-gap 1
  "Default separator width in spaces between narrow Containers columns.")

(defconst lzdockel-dashboard--container-wide-gap 2
  "Separator width in spaces between Containers columns on wider windows.")

(defconst lzdockel-dashboard--container-id-width 12
  "Fixed display width in columns for the container ID column.")

(defconst lzdockel-dashboard--container-flex-specs
  '((image   :min 16 :max 44 :weight 38)
    (created :min 10 :max 20 :weight 12)
    (ports   :min 9  :max 28 :weight 18)
    (name    :min 12 :max 36 :weight 22)
    (status  :min 10 :max 26 :weight 14))
  "Flexible column specifications for the Containers section.
Each entry has the form (KEY :min MIN :max MAX :weight WEIGHT).")

(defconst lzdockel-dashboard--section-column-specs
  `(("Containers"
     :fixed ((:id . ,lzdockel-dashboard--container-id-width))
     :header-keys (:id :image :created :ports :name)
     :flex ((image   :key :image   :min 16 :max 44 :weight 38)
            (created :key :created :min 10 :max 20 :weight 12)
            (ports   :key :ports   :min 9  :max 28 :weight 18)
            (name    :key :name    :min 12 :max 36 :weight 22)
            (status  :key :status  :min 10 :max 26 :weight 14)))
    ("Images"
     :fixed ((:id . ,lzdockel-dashboard--container-id-width))
     :header-keys (:id :repository :tag :size)
     :flex ((repository :key :repository :min 16 :max 50 :weight 52)
            (tag        :key :tag        :min 10 :max 26 :weight 32)
            (size       :key :size       :min 8  :max 14 :weight 16)))
    ("Volumes"
     :fixed nil
     :header-keys (:driver :name)
     :flex ((driver :key :driver :min 8  :max 24 :weight 20)
            (name   :key :name   :min 16 :max 72 :weight 80)))
    ("Networks"
     :fixed ((:id . ,lzdockel-dashboard--container-id-width))
     :header-keys (:id :name :driver :scope)
     :flex ((name   :key :name   :min 16 :max 44 :weight 55)
            (driver :key :driver :min 8  :max 20 :weight 25)
            (scope  :key :scope  :min 6  :max 16 :weight 20))))
  "Responsive, content-aware column layout specifications per section.")

(defvar lzdockel-dashboard-item-keymap-entries
  '((?a . (("Containers" . lzdockel-container-attach)))
    (?d . (("Containers" . lzdockel-container-delete)
           ("Images"     . lzdockel-image-delete)
           ("Volumes"    . lzdockel-volume-delete)
           ("Networks"   . lzdockel-network-delete)))
    (?i . (("Containers" . lzdockel-container-inspect)
           ("Images"     . lzdockel-image-inspect)
           ("Volumes"    . lzdockel-volume-inspect)
           ("Networks"   . lzdockel-network-inspect)))
    (?r . (("Containers" . lzdockel-container-restart)))
    (?s . (("Containers" . lzdockel-container-stop))))
  "Dispatch table mapping keys to section-specific action functions.")

(defun lzdockel-dashboard-dispatch-action (key)
  "Execute the action bound to KEY for the item and section at point."
  (unless lzdockel-dashboard--error-state
    (let* ((item (lzdockel-dashboard--item-at-point))
           (section-name (lzdockel-dashboard--section-name-at-point))
           (entries (cdr (assoc key lzdockel-dashboard-item-keymap-entries)))
           (action-fn (and section-name
                           (cdr (assoc section-name entries)))))
      (when (and item action-fn)
        (funcall action-fn item #'lzdockel-dashboard-refresh)))))

(defvar lzdockel-dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'lzdockel-dashboard-next-section)
    (define-key map (kbd "<backtab>") #'lzdockel-dashboard-prev-section)
    (define-key map (kbd "S-<tab>") #'lzdockel-dashboard-prev-section)
    (define-key map (kbd "g") #'lzdockel-dashboard-refresh)
    (define-key map (kbd "p") #'lzdockel-dashboard-pull-image)
    (define-key map (kbd "P") #'lzdockel-dashboard-view-pull-log)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "RET") #'lzdockel-dashboard-open-item)
    (define-key map (kbd "<return>") #'lzdockel-dashboard-open-item)
    (define-key map (kbd "a") (lambda () (interactive) (lzdockel-dashboard-dispatch-action ?a)))
    (define-key map (kbd "d") (lambda () (interactive) (lzdockel-dashboard-dispatch-action ?d)))
    (define-key map (kbd "i") (lambda () (interactive) (lzdockel-dashboard-dispatch-action ?i)))
    (define-key map (kbd "r") (lambda () (interactive) (lzdockel-dashboard-dispatch-action ?r)))
    (define-key map (kbd "s") (lambda () (interactive) (lzdockel-dashboard-dispatch-action ?s)))
    (define-key map (kbd "?") #'lzdockel-dashboard-help)
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
  '((((background dark))
     :background "#3d5226" :weight bold)
    (t
     :background "#d4edbc" :foreground "#1a3309" :weight bold))
  "Face for the active section header."
  :group 'lzdockel-faces)

(defface lzdockel-dashboard-item-selected
  '((((background dark))
     :background "#444444")
    (t
     :background "#e2e8f0"))
  "Face for the selected item in a section."
  :group 'lzdockel-faces)

(defface lzdockel-dashboard-column-header
  '((t :inherit font-lock-comment-face :weight bold))
  "Face for column headers in sections.")

(defvar lzdockel-dashboard-column-headers
  '(("Containers" . "  %-12s %-30s %-20s %-20s %s")
    ("Images" . "  %-12s %-30s %-15s %s")
    ("Volumes" . "  %-15s %s")
    ("Networks" . "  %-12s %-25s %-15s %s"))
  "Fallback format strings for column headers per section.
Built-in sections use dynamically computed widths from
`lzdockel-dashboard--section-column-widths'.")

(defvar lzdockel-dashboard-column-labels
  '(("Containers" . ["ID" "Image" "Created" "Ports" "Name"])
    ("Images" . ["ID" "Repository" "Tag" "Size"])
    ("Volumes" . ["Driver" "Name"])
    ("Networks" . ["ID" "Name" "Driver" "Scope"]))
  "Column labels for each section.")

(define-derived-mode lzdockel-dashboard-mode special-mode "Lzdockel-Dashboard"
  "Major mode for the lzdockel unified dashboard."
  (setq buffer-read-only t)
  (setq-local truncate-lines t)
  (hl-line-mode 1)
  (setq-local lzdockel-dashboard-current-section 0)
  (setq-local lzdockel-dashboard-data nil)
  (setq-local lzdockel-dashboard-section-bounds nil)
  (setq-local lzdockel-dashboard--error-state nil)
  (setq-local lzdockel-dashboard--override-active t)
  (setq-local lzdockel-dashboard--last-render-width nil)
  (add-hook 'window-size-change-functions
            #'lzdockel-dashboard--on-window-resize nil t))

(defun lzdockel-dashboard--unmeasured-line-number-columns (win)
  "Return extra columns to reserve for unmeasured line numbers in WIN.
Before the first redisplay of a buffer with `display-line-numbers'
enabled, `line-number-display-width' can report 0 even though a
gutter will be drawn; return a safe fallback width in that case."
  (with-current-buffer (window-buffer win)
    (if (and (bound-and-true-p display-line-numbers)
             (fboundp 'line-number-display-width)
             (zerop (with-selected-window win
                      (ceiling (line-number-display-width 'columns)))))
        (max 4 (+ 2 (or (bound-and-true-p display-line-numbers-width) 2)))
      0)))

(defun lzdockel-dashboard--available-width (&optional window)
  "Return usable display width in columns for WINDOW or current buffer.
Uses `window-max-chars-per-line' so `display-line-numbers-mode',
fringes, continuation glyphs, and font scaling are accounted for.
Falls back to `lzdockel-dashboard-default-width' when the buffer is
not displayed in any live window."
  (let ((win (or (and (windowp window) (window-live-p window) window)
                 (get-buffer-window (current-buffer) nil)
                 (get-buffer-window (current-buffer) t))))
    (if (and win (window-live-p win))
        (let ((max-chars (if (fboundp 'window-max-chars-per-line)
                             (window-max-chars-per-line win)
                           (window-body-width win)))
              (unmeasured-ln (lzdockel-dashboard--unmeasured-line-number-columns win)))
          (max 1 (- max-chars unmeasured-ln 1)))
      lzdockel-dashboard-default-width)))

(defun lzdockel-dashboard--allocate-flex-widths (budget specs)
  "Allocate BUDGET columns across flexible column SPECS.
Each element of SPECS is (KEY :min MIN :max MAX :weight WEIGHT).
Returns an alist of (KEY . WIDTH) pairs."
  (let* ((count (length specs))
         (budget (max count budget))
         (min-sum (apply #'+ (mapcar (lambda (s) (plist-get (cdr s) :min)) specs)))
         (widths (mapcar (lambda (s) (cons (car s) (plist-get (cdr s) :min))) specs)))
    (cond
     ((< budget min-sum)
      (let ((used 0)
            (remainders '()))
        (dolist (spec specs)
          (let* ((key (car spec))
                 (min-w (plist-get (cdr spec) :min))
                 (weight (plist-get (cdr spec) :weight))
                 (w (max 1 (/ (* budget min-w) min-sum)))
                 (rem (% (* budget min-w) min-sum)))
            (setcdr (assq key widths) w)
            (setq used (+ used w))
            (push (list key rem weight) remainders)))
        (let ((leftover (- budget used)))
          (cond
           ((> leftover 0)
            (setq remainders
                  (sort remainders
                        (lambda (a b)
                          (or (> (nth 1 a) (nth 1 b))
                              (and (= (nth 1 a) (nth 1 b))
                                   (> (nth 2 a) (nth 2 b)))))))
            (dolist (entry remainders)
              (when (> leftover 0)
                (let ((cell (assq (car entry) widths)))
                  (setcdr cell (1+ (cdr cell)))
                  (setq leftover (1- leftover))))))
           ((< leftover 0)
            (while (< leftover 0)
              (let ((widest nil))
                (dolist (cell widths)
                  (when (and (> (cdr cell) 1)
                             (or (null widest) (> (cdr cell) (cdr widest))))
                    (setq widest cell)))
                (if widest
                    (progn
                      (setcdr widest (1- (cdr widest)))
                      (setq leftover (1+ leftover)))
                  (setq leftover 0)))))))))
     ((> budget min-sum)
      (let ((remaining (- budget min-sum))
            (progress t))
        (while (and (> remaining 0) progress)
          (setq progress nil)
          (let ((active '())
                (weight-sum 0))
            (dolist (spec specs)
              (let* ((key (car spec))
                     (max-w (plist-get (cdr spec) :max))
                     (cur-w (cdr (assq key widths))))
                (when (or (null max-w) (< cur-w max-w))
                  (push spec active)
                  (setq weight-sum (+ weight-sum (plist-get (cdr spec) :weight))))))
            (when (and active (> weight-sum 0))
              (let ((given 0)
                    (remainders '()))
                (dolist (spec active)
                  (let* ((key (car spec))
                         (max-w (plist-get (cdr spec) :max))
                         (weight (plist-get (cdr spec) :weight))
                         (cell (assq key widths))
                         (cur-w (cdr cell))
                         (headroom (if max-w (- max-w cur-w) remaining))
                         (share (/ (* remaining weight) weight-sum))
                         (add (min headroom share))
                         (rem (% (* remaining weight) weight-sum)))
                    (when (> add 0)
                      (setcdr cell (+ cur-w add))
                      (setq given (+ given add)
                            progress t))
                    (when (or (null max-w) (< (cdr cell) max-w))
                      (push (list key rem weight max-w) remainders))))
                (setq remaining (- remaining given))
                (when (and (> remaining 0) remainders (zerop given))
                  (setq remainders
                        (sort remainders
                              (lambda (a b)
                                (or (> (nth 1 a) (nth 1 b))
                                    (and (= (nth 1 a) (nth 1 b))
                                         (> (nth 2 a) (nth 2 b)))))))
                  (dolist (entry remainders)
                    (when (> remaining 0)
                      (let* ((cell (assq (car entry) widths))
                             (max-w (nth 3 entry)))
                        (when (or (null max-w) (< (cdr cell) max-w))
                          (setcdr cell (1+ (cdr cell)))
                          (setq remaining (1- remaining)
                                progress t)))))))))))))
    widths))

(defun lzdockel-dashboard--section-field-value (section-name item col)
  "Return display string for COL of ITEM in SECTION-NAME."
  (cond
   ((string= section-name "Containers")
    (pcase col
      ('image (lzdockel-core-get item 'Image))
      ('created (lzdockel-core-get item 'RunningFor))
      ('ports (lzdockel-format-ports (lzdockel-core-get item 'Ports)))
      ('name (lzdockel-core-get item 'Names))
      ('status (lzdockel-core-get item 'Status))
      (_ "")))
   ((string= section-name "Images")
    (pcase col
      ('repository (lzdockel-core-get item 'Repository))
      ('tag (lzdockel-core-get item 'Tag))
      ('size (lzdockel-core-get item 'Size))
      (_ "")))
   ((string= section-name "Volumes")
    (pcase col
      ('driver (lzdockel-core-get item 'Driver))
      ('name (lzdockel-core-get item 'Name))
      (_ "")))
   ((string= section-name "Networks")
    (pcase col
      ('name (lzdockel-core-get item 'Name))
      ('driver (lzdockel-core-get item 'Driver))
      ('scope (lzdockel-core-get item 'Scope))
      (_ "")))
   (t "")))

(defun lzdockel-dashboard--section-content-widths (section-name items)
  "Return an alist of (COL . MAX-WIDTH) needed by ITEMS in SECTION-NAME.
Each column width is floored at its corresponding header label width."
  (let* ((spec (cdr (assoc section-name lzdockel-dashboard--section-column-specs)))
         (header-keys (plist-get spec :header-keys))
         (flex-specs (plist-get spec :flex))
         (labels (cdr (assoc section-name lzdockel-dashboard-column-labels)))
         (max-alist '()))
    ;; Seed each flexible column with its header label width (or 6 for trailing columns).
    (dolist (fspec flex-specs)
      (let* ((col (car fspec))
             (kw (plist-get (cdr fspec) :key))
             (hidx (let ((idx 0) (found nil))
                     (dolist (hk header-keys)
                       (when (eq hk kw) (setq found idx))
                       (setq idx (1+ idx)))
                     found))
             (label-w (if (and labels hidx (< hidx (length labels)))
                          (string-width (aref labels hidx))
                        6)))
        (push (cons col label-w) max-alist)))
    (dolist (item items)
      (dolist (entry max-alist)
        (let* ((col (car entry))
               (val-w (string-width
                       (lzdockel-dashboard--section-field-value section-name item col))))
          (when (> val-w (cdr entry))
            (setcdr entry val-w)))))
    (nreverse max-alist)))

(defun lzdockel-dashboard--section-column-widths (section-name &optional total-width items)
  "Compute responsive, content-aware column widths for SECTION-NAME.
TOTAL-WIDTH defaults to `lzdockel-dashboard--available-width'.
When ITEMS is non-nil, columns are sized snugly to the actual content
\(up to each column's cap) and compressed proportionally only when
content exceeds TOTAL-WIDTH.
Returns a plist of column keyword widths plus `:gap', or nil if
SECTION-NAME has no layout spec."
  (let ((spec (cdr (assoc section-name lzdockel-dashboard--section-column-specs))))
    (when spec
      (let* ((total (max 1 (or total-width (lzdockel-dashboard--available-width))))
             (gap (if (< total 95)
                      lzdockel-dashboard--container-gap
                    lzdockel-dashboard--container-wide-gap))
             (fixed (plist-get spec :fixed))
             (flex-specs (plist-get spec :flex))
             (fixed-sum (apply #'+ 0 (mapcar #'cdr fixed)))
             (total-cols (+ (length fixed) (length flex-specs)))
             (num-gaps (max 0 (1- total-cols)))
             (overhead (+ lzdockel-dashboard--container-indent
                          fixed-sum
                          (* num-gaps gap)))
             (flex-budget (- total overhead))
             (content-max (when items
                            (lzdockel-dashboard--section-content-widths section-name items)))
             (effective-specs
              (if content-max
                  (mapcar (lambda (fspec)
                            (let* ((col (car fspec))
                                   (props (cdr fspec))
                                   (min-w (plist-get props :min))
                                   (max-w (plist-get props :max))
                                   (weight (plist-get props :weight))
                                   (desired (min max-w (cdr (assq col content-max)))))
                              (list col
                                    :min (min min-w desired)
                                    :max desired
                                    :weight weight)))
                          flex-specs)
                flex-specs))
             (flex (lzdockel-dashboard--allocate-flex-widths
                    flex-budget effective-specs))
             (result (list :gap gap)))
        (dolist (fspec flex-specs)
          (let ((col (car fspec))
                (kw (plist-get (cdr fspec) :key)))
            (setq result (plist-put result kw (cdr (assq col flex))))))
        (dolist (fx fixed)
          (setq result (plist-put result (car fx) (cdr fx))))
        result))))

(defun lzdockel-dashboard--container-column-widths (&optional total-width containers)
  "Compute responsive, content-aware column widths for the Containers table.
TOTAL-WIDTH defaults to `lzdockel-dashboard--available-width'.
When CONTAINERS is non-nil, columns are sized snugly to the actual
content (up to each column's cap) and compressed proportionally only
when the content exceeds TOTAL-WIDTH."
  (lzdockel-dashboard--section-column-widths "Containers" total-width containers))

(defun lzdockel-dashboard--fit-cell (text width &optional pad)
  "Fit TEXT to display WIDTH, truncating with an ellipsis when wider.
Preserves text properties on TEXT (including on the ellipsis).
When PAD is non-nil, right-pad with spaces to exact display WIDTH."
  (let* ((str (or text ""))
         (w (max 0 width))
         (fitted
          (if (> (string-width str) w)
              (if (<= w 1)
                  (truncate-string-to-width str w)
                (let* ((props (and (> (length str) 0)
                                   (text-properties-at (1- (length str)) str)))
                       (ellipsis (if props
                                     (apply #'propertize "…" props)
                                   "…")))
                  (truncate-string-to-width str w nil nil ellipsis)))
            str)))
    (if pad
        (let ((diff (- w (string-width fitted))))
          (if (> diff 0)
              (concat fitted (make-string diff ?\s))
            fitted))
      fitted)))

(defun lzdockel-dashboard--section-header (title index)
  "Return a formatted section header string for TITLE at INDEX."
  (let* ((active (= index lzdockel-dashboard-current-section))
         (face (if active 'lzdockel-dashboard-section-active 'lzdockel-dashboard-section-header))
         (marker (if active "▸ " "  ")))
    (concat (propertize (format "%s[%d]-%s" marker (1+ index) title) 'face face) "\n")))

(defun lzdockel-dashboard--column-header (section-name &optional section-widths)
  "Return a formatted column header string for SECTION-NAME.
Uses SECTION-WIDTHS (or computes them dynamically via
`lzdockel-dashboard--section-column-widths') so headers align with
every row in the section."
  (let ((labels (cdr (assoc section-name lzdockel-dashboard-column-labels)))
        (spec (cdr (assoc section-name lzdockel-dashboard--section-column-specs))))
    (cond
     ((and spec labels)
      (let* ((widths (or section-widths
                         (lzdockel-dashboard--section-column-widths section-name)))
             (header-keys (plist-get spec :header-keys))
             (indent (make-string lzdockel-dashboard--container-indent ?\s))
             (gap (make-string (or (plist-get widths :gap)
                                   lzdockel-dashboard--container-gap)
                               ?\s))
             (last-idx (1- (length header-keys)))
             (cells '())
             (idx 0))
        (dolist (hk header-keys)
          (push (lzdockel-dashboard--fit-cell
                 (aref labels idx)
                 (plist-get widths hk)
                 (< idx last-idx))
                cells)
          (setq idx (1+ idx)))
        (let ((header-line (concat indent (mapconcat #'identity (nreverse cells) gap))))
          (concat (propertize header-line 'face 'lzdockel-dashboard-column-header) "\n"))))
     (t
      (let ((fmt (cdr (assoc section-name lzdockel-dashboard-column-headers))))
        (if (and labels fmt)
            (concat (propertize (apply #'format fmt (append labels nil))
                                'face 'lzdockel-dashboard-column-header)
                    "\n")
          ""))))))



(defun lzdockel-dashboard--container-active-p (container)
  "Return non-nil if CONTAINER is active (running)."
  (string-prefix-p "Up" (lzdockel-core-get container 'Status)))

(defun lzdockel-dashboard--sort-containers (containers)
  "Sort CONTAINERS so active ones appear first."
  (sort (copy-sequence containers)
        (lambda (a b)
          (and (lzdockel-dashboard--container-active-p a)
               (not (lzdockel-dashboard--container-active-p b))))))

(defun lzdockel-dashboard--format-container (container &optional widths)
  "Format a CONTAINER alist for display using computed column WIDTHS."
  (let* ((widths (or widths (lzdockel-dashboard--container-column-widths)))
         (id-w (plist-get widths :id))
         (image-w (plist-get widths :image))
         (created-w (plist-get widths :created))
         (ports-w (plist-get widths :ports))
         (name-w (plist-get widths :name))
         (status-w (plist-get widths :status))
         (indent (make-string lzdockel-dashboard--container-indent ?\s))
         (gap (make-string (or (plist-get widths :gap)
                               lzdockel-dashboard--container-gap)
                           ?\s))
         (id (lzdockel-core-get container 'ID))
         (short-id (substring id 0 (min id-w (length id))))
         (image (lzdockel-core-get container 'Image))
         (created (lzdockel-core-get container 'RunningFor))
         (status (lzdockel-core-get container 'Status))
         (ports (lzdockel-format-ports (lzdockel-core-get container 'Ports) ports-w))
         (names (lzdockel-core-get container 'Names))
         (exited (string-prefix-p "Exited" status))
         (status-face (cond
                       ((string-prefix-p "Up" status) 'lzdockel-status-running)
                       ((string-prefix-p "Exited" status) 'lzdockel-status-exited)
                       (t nil)))
         (status-str (if status-face
                         (propertize (lzdockel-dashboard--fit-cell status status-w nil)
                                     'face status-face)
                       ""))
         (id-cell (lzdockel-dashboard--fit-cell
                   (propertize short-id 'face 'lzdockel-image-id)
                   id-w t))
         (image-cell (lzdockel-dashboard--fit-cell image image-w t))
         (created-cell (lzdockel-dashboard--fit-cell created created-w t))
         (ports-cell (lzdockel-dashboard--fit-cell
                      (if (string-empty-p ports)
                          ""
                        (propertize ports 'face 'lzdockel-port))
                      ports-w t))
         (name-cell (lzdockel-dashboard--fit-cell
                     names name-w (not (string-empty-p status-str))))
         (line (concat indent
                       id-cell gap
                       image-cell gap
                       created-cell gap
                       ports-cell gap
                       name-cell)))
    (when exited
      (setq line (propertize line 'face 'lzdockel-dashboard-item-dim)))
    (if (string-empty-p status-str)
        line
      (concat line gap status-str))))

(defun lzdockel-dashboard--format-image (image &optional widths)
  "Format an IMAGE alist for display using computed column WIDTHS."
  (let* ((widths (or widths (lzdockel-dashboard--section-column-widths "Images")))
         (id-w (plist-get widths :id))
         (repo-w (plist-get widths :repository))
         (tag-w (plist-get widths :tag))
         (size-w (plist-get widths :size))
         (indent (make-string lzdockel-dashboard--container-indent ?\s))
         (gap (make-string (or (plist-get widths :gap)
                               lzdockel-dashboard--container-gap)
                           ?\s))
         (id (lzdockel-core-get image 'ID))
         (short-id (substring id 0 (min id-w (length id))))
         (repository (lzdockel-core-get image 'Repository))
         (tag (lzdockel-core-get image 'Tag))
         (size (lzdockel-core-get image 'Size)))
    (concat indent
            (lzdockel-dashboard--fit-cell
             (propertize short-id 'face 'lzdockel-image-id)
             id-w t)
            gap
            (lzdockel-dashboard--fit-cell repository repo-w t)
            gap
            (lzdockel-dashboard--fit-cell tag tag-w t)
            gap
            (lzdockel-dashboard--fit-cell size size-w nil))))

(defun lzdockel-dashboard--format-volume (volume &optional widths)
  "Format a VOLUME alist for display using computed column WIDTHS."
  (let* ((widths (or widths (lzdockel-dashboard--section-column-widths "Volumes")))
         (driver-w (plist-get widths :driver))
         (name-w (plist-get widths :name))
         (indent (make-string lzdockel-dashboard--container-indent ?\s))
         (gap (make-string (or (plist-get widths :gap)
                               lzdockel-dashboard--container-gap)
                           ?\s))
         (driver (lzdockel-core-get volume 'Driver))
         (name (lzdockel-core-get volume 'Name)))
    (concat indent
            (lzdockel-dashboard--fit-cell driver driver-w t)
            gap
            (lzdockel-dashboard--fit-cell name name-w nil))))

(defun lzdockel-dashboard--format-network (network &optional widths)
  "Format a NETWORK alist for display using computed column WIDTHS."
  (let* ((widths (or widths (lzdockel-dashboard--section-column-widths "Networks")))
         (id-w (plist-get widths :id))
         (name-w (plist-get widths :name))
         (driver-w (plist-get widths :driver))
         (scope-w (plist-get widths :scope))
         (indent (make-string lzdockel-dashboard--container-indent ?\s))
         (gap (make-string (or (plist-get widths :gap)
                               lzdockel-dashboard--container-gap)
                           ?\s))
         (id (lzdockel-core-get network 'ID))
         (short-id (substring id 0 (min id-w (length id))))
         (name (lzdockel-core-get network 'Name))
         (driver (lzdockel-core-get network 'Driver))
         (scope (lzdockel-core-get network 'Scope)))
    (concat indent
            (lzdockel-dashboard--fit-cell
             (propertize short-id 'face 'lzdockel-image-id)
             id-w t)
            gap
            (lzdockel-dashboard--fit-cell name name-w t)
            gap
            (lzdockel-dashboard--fit-cell driver driver-w t)
            gap
            (lzdockel-dashboard--fit-cell scope scope-w nil))))

(defun lzdockel-dashboard--format-item (item section-index &optional section-widths)
  "Format ITEM for display based on SECTION-INDEX and SECTION-WIDTHS."
  (let ((section-name (car (nth section-index lzdockel-dashboard-sections))))
    (cond
     ((string= section-name "Containers")
      (lzdockel-dashboard--format-container item section-widths))
     ((string= section-name "Images")
      (lzdockel-dashboard--format-image item section-widths))
     ((string= section-name "Volumes")
      (lzdockel-dashboard--format-volume item section-widths))
     ((string= section-name "Networks")
      (lzdockel-dashboard--format-network item section-widths))
     (t (format "  %s" item)))))

(defun lzdockel-dashboard--render-section (title index data &optional section-widths)
  "Render a section with TITLE, INDEX, and DATA items.
SECTION-WIDTHS, when non-nil, specifies the column widths plist for
this section."
  (let ((start (point))
        (widths (or section-widths
                    (lzdockel-dashboard--section-column-widths title nil data))))
    (insert (lzdockel-dashboard--section-header title index))
    (insert (lzdockel-dashboard--column-header title widths))
    (if (null data)
        (insert "  (empty)\n")
      (dolist (item data)
        (let ((p (point)))
          (insert (lzdockel-dashboard--format-item item index widths) "\n")
          (add-text-properties p (1- (point))
                               (list 'lzdockel-item item
                                     'lzdockel-section title)))))
    (insert "\n")
    (cons index (cons start (point)))))

(defun lzdockel-dashboard--ascii-art ()
  "Return lzdockel title with theme-aware styling."
  (propertize "LZDockel" 'face 'lzdockel-dashboard-title))

(defun lzdockel-dashboard-render (&optional width)
  "Render the full dashboard with all sections.
Optional WIDTH overrides the display width in columns used to lay out
section tables."
  (let* ((inhibit-read-only t)
         (render-width (or width (lzdockel-dashboard--available-width))))
    (setq lzdockel-dashboard--last-render-width render-width)
    (erase-buffer)
    (insert (lzdockel-dashboard--ascii-art) "\n\n")
    ;; (insert (make-string 50 ?═) "\n\n")
    (setq lzdockel-dashboard-section-bounds nil)
    (dotimes (i (length lzdockel-dashboard-sections))
      (let* ((section (nth i lzdockel-dashboard-sections))
             (title (car section))
             (data (cdr (assoc i lzdockel-dashboard-data)))
             (widths (lzdockel-dashboard--section-column-widths
                      title render-width data)))
        (push (lzdockel-dashboard--render-section title i (or data '()) widths)
              lzdockel-dashboard-section-bounds)))
    (setq lzdockel-dashboard-section-bounds (nreverse lzdockel-dashboard-section-bounds))
    (goto-char (point-min))))

(defun lzdockel-dashboard--on-window-resize (&optional window)
  "Re-render the dashboard when WINDOW display width changes."
  (when (and (derived-mode-p 'lzdockel-dashboard-mode)
             (not lzdockel-dashboard--error-state)
             lzdockel-dashboard-data)
    (let ((new-width (lzdockel-dashboard--available-width window)))
      (unless (eql new-width lzdockel-dashboard--last-render-width)
        (let* ((win (and (windowp window) (window-live-p window) window))
               (orig-pos (if win (window-point win) (point)))
               (orig-line (line-number-at-pos orig-pos)))
          (lzdockel-dashboard-render new-width)
          (goto-char (point-min))
          (forward-line (1- orig-line))
          (when win
            (set-window-point win (point))))))))

(defun lzdockel-dashboard--wrap-text (text max-width)
  "Wrap TEXT into a list of lines each at most MAX-WIDTH columns wide."
  (let ((words (split-string text "[ \t\n]+" t))
        (lines '())
        (current ""))
    (dolist (word words)
      (let ((candidate (if (string-empty-p current)
                           word
                         (concat current " " word))))
        (if (<= (string-width candidate) max-width)
            (setq current candidate)
          (unless (string-empty-p current)
            (push current lines))
          (if (<= (string-width word) max-width)
              (setq current word)
            (push (truncate-string-to-width word max-width nil nil "…") lines)
            (setq current "")))))
    (unless (string-empty-p current)
      (push current lines))
    (or (nreverse lines) '(""))))

(defun lzdockel-dashboard-render-error (reason &optional detail)
  "Render a styled Docker unavailable error screen for REASON and DETAIL."
  (let* ((inhibit-read-only t)
         (text-width 68)
         (missing-cli (eq reason 'missing-cli))
         (title (if missing-cli
                    "Docker CLI Not Found"
                  "Docker Engine Not Running"))
         (summary-lines
          (if missing-cli
              '("LZDockel could not find the `docker' executable on your"
                "Emacs `exec-path' / `PATH'.")
            '("The Docker CLI is installed, but the Docker daemon could"
              "not be reached.")))
         (steps
          (if missing-cli
              (list (concat "• Install " (propertize "Docker Desktop" 'face 'lzdockel-error-heading)
                            ", " (propertize "OrbStack" 'face 'lzdockel-error-heading)
                            ", or Docker Engine")
                    (concat "• Ensure " (propertize "docker" 'face 'lzdockel-error-code)
                            " is on your " (propertize "PATH" 'face 'lzdockel-error-code)
                            " / " (propertize "exec-path" 'face 'lzdockel-error-code))
                    (concat "• On macOS GUI Emacs, try "
                            (propertize "exec-path-from-shell" 'face 'lzdockel-error-code)))
            (list (concat "• macOS: Start " (propertize "Docker Desktop" 'face 'lzdockel-error-heading)
                          ", " (propertize "OrbStack" 'face 'lzdockel-error-heading)
                          ", or run " (propertize "colima start" 'face 'lzdockel-error-code))
                  (concat "• Linux: Run "
                          (propertize "sudo systemctl start docker" 'face 'lzdockel-error-code))))))
    (erase-buffer)
    (setq lzdockel-dashboard-section-bounds nil
          lzdockel-dashboard-data nil)
    (insert (lzdockel-dashboard--ascii-art) "\n\n")
    (insert "  " (propertize (concat "✖  " title) 'face 'lzdockel-error-badge) "\n\n")
    (dolist (line summary-lines)
      (insert "  " line "\n"))
    (when (and (not missing-cli) detail (not (string-empty-p detail)))
      (insert "\n  " (propertize "Detail:" 'face 'lzdockel-error-heading) "\n")
      (dolist (dline (lzdockel-dashboard--wrap-text detail text-width))
        (insert "  " (propertize dline 'face 'lzdockel-error-detail) "\n")))
    (insert "\n  " (propertize "How to fix:" 'face 'lzdockel-error-heading) "\n")
    (dolist (step steps)
      (insert "  " step "\n"))
    (insert "\n  "
            (propertize " g " 'face 'lzdockel-keycap)
            (propertize " Retry" 'face 'lzdockel-hint-label)
            "    "
            (propertize " q " 'face 'lzdockel-keycap)
            (propertize " Quit" 'face 'lzdockel-hint-label)
            "\n")
    (goto-char (point-min))))

(defun lzdockel-dashboard--fetch-sections ()
  "Fetch data for all dashboard sections and render the dashboard."
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
                           (setq lzdockel-dashboard--error-state nil
                                 lzdockel-dashboard-data (nreverse results))
                           (lzdockel-dashboard-render)))))))))))

(defun lzdockel-dashboard-fetch-all ()
  "Check Docker availability, then fetch data for all sections and render."
  (lzdockel-core-check-docker
   (lambda (status detail)
     (when (buffer-live-p (get-buffer "*lzdockel-dashboard*"))
       (with-current-buffer "*lzdockel-dashboard*"
         (if (eq status 'ok)
             (progn
               (setq lzdockel-dashboard--error-state nil)
               (lzdockel-dashboard--fetch-sections))
           (setq lzdockel-dashboard--error-state
                 (list :reason status :detail detail))
           (lzdockel-dashboard-render-error status detail)))))))

(defun lzdockel-dashboard-refresh ()
  "Refresh all dashboard data."
  (interactive)
  (lzdockel-dashboard-fetch-all))

(defun lzdockel-dashboard-pull-image ()
  "Prompt for a Docker image name and pull it asynchronously."
  (interactive)
  (unless lzdockel-dashboard--error-state
    (let ((image (string-trim
                  (read-string "Pull image (Docker Hub, e.g. nginx:latest): "))))
      (if (string-empty-p image)
          (message "Image pull aborted: no image specified.")
        (lzdockel-image-pull
         image
         (lambda ()
           (when (buffer-live-p (get-buffer "*lzdockel-dashboard*"))
             (with-current-buffer "*lzdockel-dashboard*"
               (lzdockel-dashboard-refresh)))))))))

(defun lzdockel-dashboard-view-pull-log ()
  "Open the live Docker image pull log buffer."
  (interactive)
  (lzdockel-image-show-pull-log))

(defun lzdockel-dashboard-next-section ()
  "Move to the next section."
  (interactive)
  (unless lzdockel-dashboard--error-state
    (let ((count (length lzdockel-dashboard-sections)))
      (setq lzdockel-dashboard-current-section
            (mod (1+ lzdockel-dashboard-current-section) count)))
    (lzdockel-dashboard-render)
    (lzdockel-dashboard-goto-section lzdockel-dashboard-current-section)))

(defun lzdockel-dashboard-prev-section ()
  "Move to the previous section."
  (interactive)
  (unless lzdockel-dashboard--error-state
    (let ((count (length lzdockel-dashboard-sections)))
      (setq lzdockel-dashboard-current-section
            (mod (1- lzdockel-dashboard-current-section) count)))
    (lzdockel-dashboard-render)
    (lzdockel-dashboard-goto-section lzdockel-dashboard-current-section)))

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

(defun lzdockel-dashboard-open-item ()
  "Open the item at point.
For items in the Containers section, display container logs."
  (interactive)
  (unless lzdockel-dashboard--error-state
    (let ((item (lzdockel-dashboard--item-at-point))
          (section-name (lzdockel-dashboard--section-name-at-point)))
      (when (and item (string= section-name "Containers"))
        (lzdockel-container-logs item)))))

(defun lzdockel-dashboard--command-description (command)
  "Return the first line of COMMAND's docstring, or its name if undocumented."
  (let ((doc (and (fboundp command) (documentation command))))
    (if doc
        (car (split-string doc "\n"))
      (format "%s" command))))

(defun lzdockel-dashboard--dispatch-description (key)
  "Describe what dispatch KEY does in each section.
Derived from `lzdockel-dashboard-item-keymap-entries' so the text stays
in sync with the dispatch table."
  (let* ((entries (cdr (assoc key lzdockel-dashboard-item-keymap-entries)))
         (sections (mapcar #'car entries))
         (verbs (delete-dups
                 (mapcar (lambda (entry)
                           (capitalize (car (last (split-string (symbol-name (cdr entry)) "-")))))
                         entries))))
    (format "%s the selected item (%s)."
            (mapconcat #'identity verbs " / ")
            (mapconcat #'identity sections ", "))))

(defun lzdockel-dashboard--binding-description (key-desc binding)
  "Return a human-readable description of BINDING, displayed as KEY-DESC.
Symbol bindings are described from their docstrings; dispatch lambdas
are described from `lzdockel-dashboard-item-keymap-entries'."
  (cond
   ((symbolp binding)
    (lzdockel-dashboard--command-description binding))
   ((and (= 1 (length key-desc))
         (assoc (aref key-desc 0) lzdockel-dashboard-item-keymap-entries))
    (lzdockel-dashboard--dispatch-description (aref key-desc 0)))
   (t "Dashboard action.")))

(defun lzdockel-dashboard--help-content ()
  "Return the text listing every binding of `lzdockel-dashboard-mode-map'.
The list is generated by walking the keymap itself, so it cannot drift
from the actual dashboard bindings."
  (let ((bindings '()))
    (map-keymap (lambda (key binding)
                  (let ((key-desc (key-description (vector key))))
                    (push (cons key-desc
                                (lzdockel-dashboard--binding-description key-desc binding))
                          bindings)))
                lzdockel-dashboard-mode-map)
    (let ((width (apply #'max 1 (mapcar (lambda (b) (string-width (car b))) bindings))))
      (concat
       (lzdockel-dashboard--ascii-art) " Dashboard Keybindings\n\n"
       (mapconcat (lambda (b)
                    (format "  %s%s  %s"
                            (propertize (car b) 'face 'lzdockel-keycap)
                            (make-string (- width (string-width (car b))) ?\s)
                            (cdr b)))
                  bindings "\n")
       "\n\n  "
       (propertize " q " 'face 'lzdockel-keycap)
       (propertize " Close" 'face 'lzdockel-hint-label)
       "\n"))))

(defun lzdockel-dashboard-help ()
  "Display a list of all dashboard keybindings."
  (interactive)
  (let ((buf (get-buffer-create "*lzdockel-dashboard-help*")))
    (with-current-buffer buf
      (special-mode)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (lzdockel-dashboard--help-content)))
      (goto-char (point-min)))
    (pop-to-buffer buf)))

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
