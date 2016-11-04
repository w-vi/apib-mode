;;; apib-mode.el --- Major mode for API Blueprint files -*- lexical-binding: t; -*-

;; Copyright (C) 2016 Vilibald Wanča <vilibald@wvi.cz>

;; Author: Vilibald Wanča <vilibald@wvi.cz>
;; URL: http://github.com/w-vi/apib-mode
;; Package-Requires: ((emacs "24")(markdown-mode "2.1"))
;; Version: 0.4
;; Keywords: tools, api-blueprint

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
;; apib-valid-p() which can be used in a hook for example,
;; apib-get-json() and apib-get-json-schema() to get all json or json
;; schema assets.

;;; Keybindings
;; C-c C-x j - calls apib-get-json()
;; C-c C-x s - calls apib-get-json-schema()

;;; Code:

(require 'font-lock)

(defcustom apib-drafter-executable
  (executable-find "drafter")
  "Location of the drafter API Blueprint parser executable."
  :group 'apib-mode
  :type 'file)

(defcustom apib-asset-buffer
  "*apib-assets*"
  "Name of the buffer to output json and json schema assets."
  :group 'apib-mode
  :type 'string)

(defmacro apib-with-drafter (&rest exp)
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
  (apib-with-drafter
   (set (make-local-variable 'compile-command)
        (concat apib-drafter-executable " -lu " buffer-file-name))
   (compile compile-command)))

(defun apib-valid-p ()
  "Validate the buffer and return true if the buffer is valid."
  (apib-with-drafter
   (if (= 0 (call-process
             apib-drafter-executable buffer-file-name nil nil "-lu"))
       t nil)))


(defun apib-refract-element-p (element type)
  "Is refract ELEMENT of type TYPE?"
  (if (string= (plist-get element :element) type) t nil))

(defun apib-refract-mapc (func element)
  "Call FUNC on each of the refract elements in ELEMENT."
  (while element
    (funcall func element)
    (when (vectorp element)
        (mapc
         (lambda (e)
           (apib-refract-mapc func e))
         element)
        (setq element nil))
    (setq element (plist-get element :content))))


(defun apib-get-assets (content-type)
  "Return list of content of all asset elements of CONTENT-TYPE.
It takes the current API Bleuprint buffer as an input."
  (let ((parse-result (apib--parse))
        (result nil))
    (when parse-result
      (apib-refract-mapc
       (lambda (e)
         (when (apib-refract-element-p e "asset")
           (when (string= content-type (plist-get
                                        (plist-get e :attributes)
                                        :contentType))
             (push (plist-get e :content) result))))
       parse-result))
    result))


(defun apib-print-assets (content-type)
  "Print all the assets of type CONTENT-TYPE from current API Blueprint buffer."
  (with-output-to-temp-buffer apib-asset-buffer
    (mapc
     (lambda (e)
       (princ e)
       (princ "\n\n"))
     (apib-get-assets content-type))))


(defun apib-get-json-schema ()
  "Print JSON schema for all endpoints in the current API Bleuprint."
  (interactive)
  (apib-print-assets "application/schema+json"))


(defun apib-get-json ()
  "Print JSON schema for all endpoints in the current API Bleuprint."
  (interactive)
  (apib-print-assets "application/json"))


(defun apib--parse()
  "Return refract parse result of current API Blueprint in the buffer."
  (apib-with-drafter
   (let ((json-object-type 'plist))
     (let ((result (json-read-from-string
                    (shell-command-to-string
                     (concat
                      apib-drafter-executable
                      " -f json -u "
                      buffer-file-name)))))
     (if (apib-refract-element-p result "parseResult")
         result
       (progn (display-warning
               'apib-mode
               "Could not parse the document")
              (nil)))))))


(defun apib--error-filename ()
  "Find the buffer file name in the compilation output."
  ; Need to save matching data otherwise the matching groups are
  ; screwed, basically everything needs to be saved.
  (save-match-data
    (save-excursion
      (when (re-search-backward "^.*?drafter.+?\\(/.+\\)$" (point-min) t)
        (list (match-string 1))))))


;;; Keybindings
(defvar apib-mode-map nil "Keymap for `apib-mode'.")
(progn
  (setq apib-mode-map (make-sparse-keymap))
  (define-key apib-mode-map (kbd "C-c C-x j") 'apib-get-json)
  (define-key apib-mode-map (kbd "C-c C-x s") 'apib-get-json-schema)
  )

;;;###autoload
(define-derived-mode apib-mode markdown-mode
  "apib"
  "API Blueprint major mode."
  :group 'apib-mode

  (font-lock-add-keywords
   nil
   '(("\\(?:\\(?:\\+\\|\\-\\) +\\(?:Body\\|Headers?\\|Model\\|Parameters?\\|Re\\(?:quest\\)\\|Schema\\|Values\\)\\)"
      0
      font-lock-keyword-face)

     ("\\(\\(?:\\+\\|\\-\\) +Response\\) +\\([0-9]\\{3\\}\\)+(?\\(.*\\))?"
      (1 font-lock-keyword-face)
      (2 font-lock-constant-face)
      (3 font-lock-variable-name-face))

     ("\\(\\(?:\\+\\|\\-\\) +Attributes\\)+(?\\(.*\\))?"
      (1 font-lock-keyword-face)
      (2 font-lock-variable-name-face))

     ;; Property
     ("^ *\\(?:\\+\\|\\-\\) +\\(.+?\\)\\(?:: +\\([^(\n]+\\)\\)?\\(?: +(\\(.*\\))\\)?\\(?: *- *.*\\)?$"
       (1 nil)
       (2 font-lock-constant-face nil t)
       (3 font-lock-constant-face nil t))))

  (set (make-local-variable 'compile-command)
       (if (null apib-drafter-executable)
           (progn (display-warning
                   'apib-mode
                   "drafter binary not found, please install it in your exec-path")
                  (nil))
         (concat apib-drafter-executable " -f json -u " buffer-file-name)))
  (setq indent-tabs-mode nil)
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
