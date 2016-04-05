;;; apib-mode.el --- Major mode for API Blueprint files -*- lexical-binding: t; -*-

;; Copyright (C) 2016 Vilibald Wanča <vilibald@wvi.cz>

;; Author: Vilibald Wanča <vilibald@wvi.cz>
;; URL: http://github.com/w-vi/apib-mode
;; Package-Requires: ((emacs "24")(markdown-mode "2.1"))
;; Version: 0.1
;; Keywords: API Blueprint

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see http://www.gnu.org/licenses/.

;;; Commentary:

;; apib-mode is a major mode for editing API Blueprint in GNU Emacs.
;; It is derived from markdown mode as apib is a special case of
;; markdown.  It adds couple of usefull things when working with API
;; Blueprint like getting parsing the API Blueprint and validating it.
;; For this to work though you need to install the drafter exectubale
;; first, please see https://github.com/apiaryio/drafter for more
;; information

;;; Installation:

;; (autoload 'apib-mode "apib-mode"
;;        "Major mode for editing API Blueprint files" t)
;; (add-to-list 'auto-mode-alist '("\\.apib\\'" . apib-mode))
;;

;;; Usage:

;; It has all the features of markdown mode. Visit
;; http://jblevins.org/projects/markdown-mode/ to see the details. To
;; validate your API Blueprint or see the parse result just compile it
;; using either M-x compile or your key binding for compile.  It also
;; provides some convenience functions: apib-validate(),
;; apib-valid-p() which can be used in a hook for example.

;;; Code:

(require 'font-lock)

(defcustom apib-drafter-executable
  (executable-find "drafter")
  "Location of the drafter API Blueprint parser executable."
  :group 'apib-mode
  :type 'file)

(defmacro with-drafter (&rest exp)
  "Helper verifying that drafter binary is present before it proceeds with EXP."
  `(if (null apib-drafter-executable)
       (progn (display-warning
               'apib-mode
               "drafter binary not found, please install it in your exec-path")
              (nil))
     (progn ,@exp)))

(defun apib-validate ()
  "Validates the buffer.
This actually runs drafter binary but only validates the file
with parsing output."
  (interactive)
  (with-drafter
   (set (make-local-variable 'compile-command)
        (concat apib-drafter-executable " -lu " buffer-file-name))
   (compile compile-command)))

(defun apib-valid-p ()
  "Validates the buffer and returns true if the buffer is valid."
  (with-drafter
   (if (= 0 (call-process
             apib-drafter-executable buffer-file-name nil nil "-lu"))
       t nil)))

(defun apib--error-filename ()
  "Find the buffer file name in the compilation output."
  ; Need to save matching data otherwise the matching groups are
  ; screwed, basically everything needs to be saved.
  (save-match-data
    (save-excursion
      (when (re-search-backward "^.*?drafter.+?\\(/.+\\)$" (point-min) t)
        (list (match-string 1))))))

;;;###autoload
(define-derived-mode apib-mode markdown-mode
  "apib"
  "API Blueprint major mode."
  :group 'apib-mode
  (font-lock-add-keywords
   nil
   '(("\\(?:\\(?:\\+\\|\\-\\) +\\(?:Body\\|Headers?\\|Model\\|Parameters?\\|Re\\(?:quest\\|sponse\\)\\|Schema\\|Values\\)\\)"
      0
      font-lock-variable-name-face)))

  (set (make-local-variable 'compile-command)
       (if (null apib-drafter-executable)
           (progn (display-warning
                   'apib-mode
                   "drafter binary not found, please install it in your exec-path")
                  (nil))
         (concat apib-drafter-executable " -f json -u " buffer-file-name)))

  (eval-after-load "compilation"
    (progn
      (add-to-list 'compilation-error-regexp-alist-alist
                   '(apib
                     "^\\(?:warning\\|error\\):.+?line \\([0-9]+\\), column \\([0-9]+\\) - line \\([0-9]+\\), column \\([0-9]+\\).*$"
                     apib--error-filename 3 4))
      (add-to-list 'compilation-error-regexp-alist
                   'apib))))
(provide 'apib-mode)
;;; apib-mode.el ends here
