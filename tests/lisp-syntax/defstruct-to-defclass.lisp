(defpackage :lem-tests/lisp-syntax/defstruct-to-defclass
  (:use :cl)
  (:import-from :lem-base)
  (:import-from :lem-tests/utilities
                :sample-file)
  (:import-from :lem-lisp-syntax.defstruct-to-defclass
                :defstruct-to-defclass
                :analyze-defstruct
                :make-struct-info
                :struct-info-p
                :struct-start-point
                :struct-end-point
                :struct-name
                :struct-name-and-options-point
                :struct-slot-descriptions
                :slot-description-info-p
                :slot-description-name
                :slot-description-point
                :slot-description-initial-value-start-point
                :slot-description-initial-value-end-point
                :slot-description-read-only-p
                :slot-description-type-start-point
                :slot-description-type-end-point
                :translate-to-defclass-with-info)
  (:import-from :rove))
(in-package :lem-tests/lisp-syntax/defstruct-to-defclass)

(defun expected-point-position-p (point line-number charpos)
  (and (= line-number (lem-base:line-number-at-point point))
       (= charpos (lem-base:point-charpos point))))

(defun form-string-at-point (point)
  (lem-base:with-point ((start point)
                        (end point))
    (loop :while (lem-base:scan-lists start -1 1 t))
    (loop :until (lem-base:blank-line-p end) :do (lem-base:line-offset end 1))
    (lem-base:line-end end)
    (lem-base:points-to-string start end)))

(defun search-input-defstruct (point n)
  (lem-base:buffer-start point)
  (lem-base:search-forward point ";;; input")
  (loop :repeat n
        :do (lem-base:search-forward point "(defstruct"))
  (lem-base:scan-lists point -1 1 t))

(defun fetch-expected-form-string (buffer n)
  (lem-base:with-point ((point (lem-base:buffer-point buffer)))
    (lem-base:buffer-start point)
    (lem-base:search-forward point ";;; output")
    (loop :repeat n
          :do (lem-base:search-forward point "(defclass"))
    (form-string-at-point point)))

(defun make-test-buffer ()
  (let ((buffer (lem-base:find-file-buffer (sample-file "defstruct-to-defclass.lisp")
                                           :temporary t
                                           :syntax-table lem-lisp-syntax:*syntax-table*)))
    (setf (lem-base:variable-value 'lem-base:calc-indent-function :buffer buffer)
          'lem-lisp-syntax:calc-indent)
    buffer))

(rove:deftest analyze-defstruct
  (rove:testing "simple"
    (let* ((buffer (make-test-buffer))
           (point (lem-base:buffer-point buffer)))
      (search-input-defstruct point 1)
      (let ((info (analyze-defstruct point (make-struct-info))))
        (rove:ok (struct-info-p info))
        (rove:ok (equal "foo" (struct-name info)))
        (rove:ok (expected-point-position-p (struct-start-point info) 3 1))
        (rove:ok (expected-point-position-p (struct-end-point info) 6 8))
        (rove:ok (expected-point-position-p (struct-name-and-options-point info) 3 11))
        (let ((slots (struct-slot-descriptions info)))
          (rove:ok (= (length slots) 3))
          (let ((slot (first slots)))
            (rove:ok (slot-description-info-p slot))
            (rove:ok (equal (slot-description-name slot) "slot-a"))
            (rove:ok (expected-point-position-p (slot-description-point slot) 4 2)))
          (let ((slot (second slots)))
            (rove:ok (slot-description-info-p slot))
            (rove:ok (equal (slot-description-name slot) "slot-b"))
            (rove:ok (expected-point-position-p (slot-description-point slot) 5 2)))
          (let ((slot (third slots)))
            (rove:ok (slot-description-info-p slot))
            (rove:ok (equal (slot-description-name slot) "slot-c"))
            (rove:ok (expected-point-position-p (slot-description-point slot) 6 2)))))))
  (rove:testing "slot-description"
    (let* ((buffer (make-test-buffer))
           (point (lem-base:buffer-point buffer)))
      (search-input-defstruct point 3)
      (let ((info (analyze-defstruct point (make-struct-info))))
        (rove:ok (struct-info-p info))
        (rove:ok (equal "foo" (struct-name info)))
        (let ((slots (struct-slot-descriptions info)))
          (rove:ok (= (length slots) 11))
          (rove:testing "a"
            (let ((slot (first slots)))
              (rove:ok (slot-description-info-p slot))
              (rove:ok (equal (slot-description-name slot) "a"))
              (rove:ok (equal "12"
                              (lem-base:points-to-string (slot-description-initial-value-start-point slot)
                                                         (slot-description-initial-value-end-point slot))))
              (rove:ok (null (slot-description-type-start-point slot)))
              (rove:ok (null (slot-description-type-end-point slot)))
              (rove:ok (null (slot-description-read-only-p slot)))))
          (rove:testing "b"
            (let ((slot (second slots)))
              (rove:ok (slot-description-info-p slot))
              (rove:ok (equal (slot-description-name slot) "b"))
              (rove:ok (equal "nil"
                              (lem-base:points-to-string
                               (slot-description-initial-value-start-point slot)
                               (slot-description-initial-value-end-point slot))))
              (rove:ok (null (slot-description-type-start-point slot)))
              (rove:ok (null (slot-description-type-end-point slot)))
              (rove:ok (null (slot-description-read-only-p slot)))))
          (rove:testing "c"
            (let ((slot (third slots)))
              (rove:ok (equal (slot-description-name slot) "c"))
              (rove:ok (equal '(let ((x 0)) (f x))
                              (read-from-string
                               (lem-base:points-to-string
                                (slot-description-initial-value-start-point slot)
                                (slot-description-initial-value-end-point slot)))))
              (rove:ok (null (slot-description-type-start-point slot)))
              (rove:ok (null (slot-description-type-end-point slot)))
              (rove:ok (null (slot-description-read-only-p slot)))))
          (rove:testing "d"
            (let ((slot (fourth slots)))
              (rove:ok (equal (slot-description-name slot) "d"))
              (rove:ok (equal "100"
                              (lem-base:points-to-string
                               (slot-description-initial-value-start-point slot)
                               (slot-description-initial-value-end-point slot))))
              (rove:ok (equal "integer"
                              (lem-base:points-to-string (slot-description-type-start-point slot)
                                                         (slot-description-type-end-point slot))))
              (rove:ok (null (slot-description-read-only-p slot)))))
          (rove:testing "e"
            (let ((slot (fourth slots)))
              (rove:ok (equal (slot-description-name slot) "e"))
              (rove:ok (equal "nil"
                              (lem-base:points-to-string
                               (slot-description-initial-value-start-point slot)
                               (slot-description-initial-value-end-point slot))))
              (rove:ok (equal '(or nil string)
                              (read-from-string (lem-base:points-to-string (slot-description-type-start-point slot)
                                                                           (slot-description-type-end-point slot)))))
              (rove:ok (null (slot-description-read-only-p slot)))))
          (rove:testing "f"
            (let ((slot (fourth slots)))
              (rove:ok (equal (slot-description-name slot) "f"))
              (rove:ok (equal '(progn (foo))
                              (lem-base:points-to-string
                               (slot-description-initial-value-start-point slot)
                               (slot-description-initial-value-end-point slot))))
              (rove:ok (equal "symbol"
                              (lem-base:points-to-string (slot-description-type-start-point slot)
                                                         (slot-description-type-end-point slot))))
              (rove:ok (null (slot-description-read-only-p slot)))))
          (rove:testing "g"
            (let ((slot (fourth slots)))
              (rove:ok (equal (slot-description-name slot) "g"))
              (rove:ok (equal "nil"
                              (lem-base:points-to-string
                               (slot-description-initial-value-start-point slot)
                               (slot-description-initial-value-end-point slot))))
              (rove:ok (null (slot-description-type-start-point slot)))
              (rove:ok (null (slot-description-type-end-point slot)))
              (rove:ok (eq t (slot-description-read-only-p slot)))))
          (rove:testing "h"
            (let ((slot (fourth slots)))
              (rove:ok (equal (slot-description-name slot) "h"))
              (rove:ok (equal "nil"
                              (lem-base:points-to-string
                               (slot-description-initial-value-start-point slot)
                               (slot-description-initial-value-end-point slot))))
              (rove:ok (null (slot-description-type-start-point slot)))
              (rove:ok (null (slot-description-type-end-point slot)))
              (rove:ok (null (slot-description-read-only-p slot)))))
          (rove:testing "i"
            (let ((slot (fourth slots)))
              (rove:ok (equal (slot-description-name slot) "i"))
              (rove:ok (equal "nil"
                              (lem-base:points-to-string
                               (slot-description-initial-value-start-point slot)
                               (slot-description-initial-value-end-point slot))))
              (rove:ok (eq t (slot-description-read-only-p slot)))))
          (rove:testing "j"
            (let ((slot (fourth slots)))
              (rove:ok (equal (slot-description-name slot) "j"))
              (rove:ok (equal "1"
                              (lem-base:points-to-string
                               (slot-description-initial-value-start-point slot)
                               (slot-description-initial-value-end-point slot))))
              (rove:ok (equal "integer"
                              (lem-base:points-to-string (slot-description-type-start-point slot)
                                                         (slot-description-type-end-point slot))))
              (rove:ok (eq t (slot-description-read-only-p slot)))))
          (rove:testing "k"
            (let ((slot (fourth slots)))
              (rove:ok (equal (slot-description-name slot) "k"))
              (rove:ok (equal "2"
                              (lem-base:points-to-string
                               (slot-description-initial-value-start-point slot)
                               (slot-description-initial-value-end-point slot))))
              (rove:ok (equal "integer"
                              (lem-base:points-to-string (slot-description-type-start-point slot)
                                                         (slot-description-type-end-point slot))))
              (rove:ok (eq t (slot-description-read-only-p slot))))))))))

(rove:deftest defstruct-to-defclass
  (flet ((test (n)
           (rove:testing (format nil "case-~D" n)
             (let* ((buffer (make-test-buffer))
                    (expected-form-string (fetch-expected-form-string buffer n))
                    (point (lem-base:buffer-point buffer)))
               (search-input-defstruct point n)
               (defstruct-to-defclass point)
               (rove:ok (equal (form-string-at-point point)
                               expected-form-string))))))
    (test 1)
    (test 2)
    (test 3)))
