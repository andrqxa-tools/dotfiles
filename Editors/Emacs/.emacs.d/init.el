(when (memq window-system '(x pgtk wayland))
  (use-package exec-path-from-shell
    :ensure t
    :config
    (exec-path-from-shell-initialize)))
    
;; =============================
;; Package system
;; =============================
(require 'package)

(setq package-archives
      '(("gnu"   . "https://elpa.gnu.org/packages/")
        ("melpa" . "https://melpa.org/packages/")))

(unless package-archive-contents
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; =============================
;; Profile (ide | lean)
;; =============================
(defconst my/profile
  (intern (or (getenv "EMACS_PROFILE") "ide")))

(message "Emacs profile: %s" my/profile)

;; =============================
;; UI / basics
;; =============================
;;(setq inhibit-startup-screen t)
;;(menu-bar-mode -1)
;;(tool-bar-mode -1)
;;(scroll-bar-mode -1)

(setq ring-bell-function 'ignore)

(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)

;; =============================
;; Completion (IDE only)
;; =============================
(when (eq my/profile 'ide)
  (use-package corfu
    :init
    (global-corfu-mode)
    :custom
    (corfu-auto t)
    (corfu-auto-delay 0.1)
    (corfu-auto-prefix 1)
    (corfu-cycle t)))

;; =============================
;; Project management
;; =============================
(use-package project
  :ensure nil)

;; =============================
;; Git (IDE only)
;; =============================
(when (eq my/profile 'ide)
  (use-package magit))

;; =============================
;; LSP (eglot)
;; =============================
(use-package eglot
  :ensure nil
  :config
  (add-to-list 'eglot-server-programs '(go-mode . ("gopls")))
  (setq eglot-autoshutdown t
        eglot-send-changes-idle-time 0.5))

;; =============================
;; Go config
;; =============================
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'go-config)
;; Keep Customize's auto-written settings out of init.el.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))
