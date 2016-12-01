;;; apib-mode-test.el --- apib mode tests

;;; Commentary:

;; Run standalone with this,
;;   emacs -batch -L . -l apib-mode-test.el -f ert-run-tests-batch

;;; Code:

(require 'ert)
(require 'apib-mode)
(require 'json)

(ert-deftest apib-test-validate ()
  "Test the validate function."
  (with-current-buffer (find-file-noselect "apibs/test-validate.apib")
    (apib-validate))
  (with-current-buffer apib-result-buffer
    (should-not
     (null
      (search-forward-regexp (concat "^" apib-drafter-executable " -lu .*test-validate.apib$") nil t)))))


(ert-deftest apib-test-parse ()
  "Test the parse function."
  (with-current-buffer (find-file-noselect "apibs/test-validate.apib")
    (apib-parse))
  (with-current-buffer apib-result-buffer
    (should-not
     (null
      (search-forward-regexp (concat "^" apib-drafter-executable " -f json -u .*test-validate.apib$") nil t)))))


(ert-deftest apib-test-json ()
  "Test the get-json function."
  (with-current-buffer (find-file-noselect "apibs/test-assets.apib")
    (apib-get-json))
  (with-current-buffer apib-asset-buffer
    (should
     (string-equal
      (json-encode (json-read-from-string (buffer-string)))
      (json-encode
       (json-read-from-string
        "{\"id\":6161,\"user\":\"wvi\",\"active\":false,\"social\":{\"github\":{\"active\":true,\"id\":1234,\"uri\":\"wvi\"}}}"))))))


(ert-deftest apib-test-json-schema ()
  "Test the get-json-schema function."
  (with-current-buffer (find-file-noselect "apibs/test-assets.apib")
    (apib-get-json-schema))
  (with-current-buffer apib-asset-buffer
    (should
     (string-equal
      (json-encode (json-read-from-string (buffer-string)))
      (json-encode
       (json-read-from-string
        "{\"$schema\":\"http://json-schema.org/draft-04/schema#\",\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"number\"},\"user\":{\"type\":\"string\"},\"active\":{\"type\":\"boolean\"},\"social\":{\"type\":\"object\",\"properties\":{\"github\":{\"type\":\"object\",\"properties\":{\"active\":{\"type\":\"boolean\"},\"id\":{\"type\":\"number\"},\"uri\":{\"type\":\"string\"}}}}}}}"))))))

