;; -*- lexical-binding: t -*-

(defgroup org-calendar-sync nil
  "Settings for calendar synchronization"
  :group 'org)

(defcustom org-calendar-binary "org_calendar"
  "Path to the calendar synchronization binary"
  :type 'string
  :group 'org-calendar-sync)

(defcustom org-calendar-configs nil
  "List of calendar configurations.
Each configuration should be a plist with these properties:
:url      - URL of the ICS calendar
:output   - Path to output org file
:tags     - Org-mode tags for events (e.g. \":work:\")
:weeks    - Number of weeks to fetch
:update-interval - Sync interval in seconds (0 for manual only)"
  :type '(repeat (plist :options ((:url (string :tag "Calendar URL"))
                                (:output (file :tag "Output file"))
                                (:tags (string :tag "Org tags"))
                                (:weeks (integer :tag "Weeks to fetch"))
                                (:update-interval (integer :tag "Update interval (seconds)"))))
  :group 'org-calendar-sync))

(defun update-calendar-from-ics (&rest args)
  "Synchronize calendar with given parameters without displaying buffer.
ARGS should be a plist with keys:
:url - Calendar URL
:output - Output org file path
:tags - Org tags string
:weeks - Number of weeks to fetch"
  (interactive)
  (let ((url (plist-get args :url))
        (output (expand-file-name (plist-get args :output)))
        (tags (plist-get args :tags))
        (weeks (or (plist-get args :weeks) 2))
        (buffer (generate-new-buffer " *temp calendar sync*")) ; Hidden buffer (space in name)
        (display-buffer-alist display-buffer-alist)) ; Save original display settings
    
    ;; Temporarily suppress all command messages
    (let ((inhibit-message t)
          (message-log-max nil))
      
      ;; Verify binary exists
      (unless (executable-find org-calendar-binary)
        (error "Binary '%s' not found in PATH!" org-calendar-binary))
      
      ;; Run command completely silently
      (make-process
       :name "org-calendar-sync"
       :buffer buffer
       :command (list org-calendar-binary
                      "--url" url
                      "--output" output
                      "--tags" tags
                      "--weeks" (number-to-string weeks)))
      
      ;; Setup callback
      (set-process-sentinel 
       (get-buffer-process buffer)
       (lambda (process event)
         (when (string-match "finished" event)
           ;; Refresh buffer if file is open
           (when (get-file-buffer output)
             (with-current-buffer (get-file-buffer output)
               (revert-buffer t t t)))
           (message "Calendar updated: %s" output)
           ;; Clean up
           (when (buffer-live-p buffer)
             (kill-buffer buffer))))))))

;; (defun update-calendar-from-ics (&rest args)
;;   "Synchronize calendar with given parameters.
;; ARGS should be a plist with keys:
;; :url - Calendar URL
;; :output - Output org file path
;; :tags - Org tags string
;; :weeks - Number of weeks to fetch"
;;   (interactive)
;;   (let ((url (plist-get args :url))
;;         (output (expand-file-name (plist-get args :output)))
;;         (tags (plist-get args :tags))
;;         (weeks (or (plist-get args :weeks) 2))
;;         (buffer (get-buffer-create "*Calendar Sync*"))) ; Save original value

;;     ;; Verify binary exists
;;     (unless (executable-find org-calendar-binary)
;;       (error "Binary '%s' not found in PATH!" org-calendar-binary))
    
;;     (message "Syncing calendar to %s..." output)
    
;;     ;; Run sync command asynchronously
;;     (async-shell-command 
;;      (format "%s --url '%s' --output '%s' --tags '%s' --weeks %d"
;;              org-calendar-binary url output tags weeks)
;;      buffer)
    
;;     ;; Setup callback when process completes
;;     (set-process-sentinel
;;      (get-buffer-process buffer)
;;      (lambda (process event)
;;        (when (string-match "finished" event)
;;          ;; Refresh buffer if file is open
;;          (when (get-file-buffer output)
;;            (with-current-buffer (get-file-buffer output)
;;              (revert-buffer t t t)))
;;          (message "Calendar updated: %s" output))))))

(defun setup-calendar-sync-timers ()
  "Initialize sync timers for all configured calendars"
  (interactive)
  (dolist (config org-calendar-configs)
    (let ((interval (plist-get config :update-interval)))
      (when (and interval (> interval 0))
        ;; Create timer for this calendar config
        (run-at-time nil interval 
                    (lambda (conf)
                      (apply #'update-calendar-from-ics conf))
                    config)))))

;; ;; Initialize when org-mode loads
;; (eval-after-load 'org
;;   '(progn
;;      ;; Add all output files to org-agenda
;;      (dolist (config org-calendar-configs)
;;        (add-to-list 'org-agenda-files 
;;                    (expand-file-name (plist-get config :output))))
     
;;      ;; Start sync timers
;;      (setup-calendar-sync-timers)
     
;;      ;; Initial sync after Emacs starts
;;      (run-with-idle-timer 10 nil #'setup-calendar-sync-timers)))

(provide 'org-calendar-sync)
