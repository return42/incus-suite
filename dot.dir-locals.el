;; SPDX-License-Identifier: AGPL-3.0-or-later

;; (setq enable-dir-local-variables t)

((nil
  . ((fill-column . 80)
     (indent-tabs-mode . nil)
     (eval . (setq-local prj-root (locate-dominating-file  default-directory ".dir-locals.el")))
     (eval . (make-local-variable 'exec-path))
     ;; (eval . (add-to-list 'exec-path (expand-file-name "./bin" prj-root)))
     ))
 (sh-mode
  . (
     (sh-shell . "bash")
     (eval . (flycheck-mode t))
     ))
 (makefile-mode
  . (
     (indent-tabs-mode . t)
     (eval . (flycheck-mode t))
     ))
 )
