(in-package :color-gradients)

(defun dist (x1 y1 x2 y2)
  (let ((xd (- x2 x1))
	(yd (- y2 y1)))
    (sqrt (+ (* xd xd) (* yd yd)))))

(defun gen-calc-col (d c1 c2 dither)
  (flet ((wav (a b d1 d2)
	   (/ (+ (* a d1)(* b d2)) d))
	 (wav-dither (a b d1 d2)
	   (+ (/ (+ (* a d1)(* b d2)) d) (- (random dither) (/ dither 2)))))
    (let ((wavf (if (zerop dither) #'wav #'wav-dither)))
     #'(lambda (d1 d2)
	 (declare (inline wav wav-dither))
	 (if (> d1 d)
	   c2
	   (if (> d2 d)
	     c1
	     (mapcar #'(lambda (x y) (max 0 (min (round (funcall wavf x y d1 d2)) 255)))
		     c2 c1)))))))

(defun ensure-rgba (color)
  (destructuring-bind (r g b . pa) color
    (check-type r (integer 0 255))
    (check-type g (integer 0 255))
    (check-type b (integer 0 255))
    (if (and (consp pa)
	     (typep (car pa) '(integer 0 255)))
	color
	(list r g b 255))))

(defun precompute-color-table (color1 color2 steps)
  (let ((color-table (make-array steps :element-type 'list)))
    (flet ((wav (a b frac)
	     (round (+ (* a frac)(* b (- 1 frac))))))
     (destructuring-bind (r1 g1 b1 a1) (ensure-rgba color1)
       (destructuring-bind (r2 g2 b2 a2) (ensure-rgba color2)
	 (dotimes (k steps color-table)
	   (let ((frac (/ k steps)))
	     (setf (aref color-table k) (list (wav r1 r2 frac)
					      (wav g1 g2 frac)
					      (wav b1 b2 frac)
					      (wav a1 a2 frac))))))))))

(defun make-linear-gradient (point-1 point-2
			     &key (color-1 '(0 0 0 255)) (color-2 '(255 255 255 255))
			          (steps 500) (table nil))
  (destructuring-bind (x1 y1) point-1
    (destructuring-bind (x2 y2) point-2
      (cond
	((and (= x1 x2)
	      (= y1 y2))
	 (error "Points defining a gradient must be different."))
	((= x1 x2)
	 (make-linear-vertical-gradient point-1 point-2
					:color-1 color-1 :color-2 color-2 :steps steps :table table))
	((= y1 y2)
	 (make-linear-horizontal-gradient point-1 point-2
					  :color-1 color-1 :color-2 color-2 :steps steps :table table))
	(t (make-linear-general-griadient point-1 point-2
					  :color-1 color-1 :color-2 color-2 :steps steps :table table))))))

(defun make-linear-vertical-gradient (point-1 point-2 &key color-1 color-2 steps table)
  (let ((color-table (if table
			 table
			 (precompute-color-table color-1 color-2 steps))))
    (destructuring-bind (x1 y1) point-1
      (declare (ignore x1))
      (destructuring-bind (x2 y2) point-2
	(declare (ignore x2))
	(let ((d (abs (- y2 y1)))
	      (last-step (1- (array-dimension color-table 0))))
	 (values #'(lambda (x y)
		     (declare (ignore x))
		     (let ((d1 (abs (- y y1)))
			   (d2 (abs (- y y2))))
		      (aref color-table
			    (cond ((> d1 d) (aref color-table last-step))
				  ((> d2 d) (aref color-table 0))
				  (t (aref color-table (round (* last-step (/ d1 d)))))))))
		 color-table))))))

(defun make-linear-horizontal-gradient (point-1 point-2 &key color-1 color-2 steps table)
  (let ((color-table (if table
			 table
			 (precompute-color-table color-1 color-2 steps))))
    (destructuring-bind (x1 y1) point-1
      (declare (ignore y1))
      (destructuring-bind (x2 y2) point-2
	(declare (ignore y2))
	(let ((d (abs (- x2 x1)))
	      (last-step (1- (array-dimension color-table 0))))
	 (values #'(lambda (x y)
		     (declare (ignore y))
		     (let ((d1 (abs (- x x1)))
			   (d2 (abs (- x x2))))
		      (aref color-table
			    (cond ((> d1 d) (aref color-table last-step))
				  ((> d2 d) (aref color-table 0))
				  (t (aref color-table (round (* last-step (/ d1 d)))))))))
		 color-table))))))

(defun make-linear-general-griadient (point-1 point-2 &key color-1 color-2 steps table)
  (let ((color-table (if table
			 table
			 (precompute-color-table color-1 color-2 steps))))
    (destructuring-bind (x1 y1) point-1
      (destructuring-bind (x2 y2) point-2
	(let ((A (cond
		   ((and (zerop x1)(zerop y1)) (/ y2 x2))
		   ((and (zerop x2)(zerop y2)) (/ y1 x1))
		   ((and (not (zerop y2))(not (zerop x2))(= (/ y1 y2)(/ x1 x2))) 1)
		   (t (/ (- y1 y2)(- (* y2 x1)(* x2 y1))))))
	      (B (cond
		   ((or (and (zerop x1)(zerop y1))
			(and (zerop x2)(zerop y2))) -1)
		   ((and (not (zerop y2))(not (zerop x2))(= (/ y1 y2)(/ x1 x2))) -1)
		   (t (/ (- x2 x1)(- (* y2 x1)(* x2 y1))))))
	      (d (dist x1 y1 x2 y2)))
	  (let ((AB (/ A B))
		(C1 (/ (* A B) (+ (* A A) (* B B))))
		(C2 (- y1 (* (/ B A) x1)))
		(C4 (- y2 (* (/ B A) x2)))
		(C3 (- (/ (* A A) (+ (* A A)(* B B))))))
	    (let ((C3+ (1+ C3))
		  (C5 (* C3 C2))
		  (C6 (* C3 C4)))
	      (values
	       #'(lambda (x y)
		   (let ((V1 (+ (* AB x) y)))
		     (let ((d1 (dist i j (* C1 (- V1 C2)) (- (* C3+ V1) C5)))
			   (d2 (dist i j (* C1 (- V1 C4)) (- (* C3+ V1) C6))))
		       (cond ((> d1 d) (aref color-table last-step))
			     ((> d2 d) (aref color-table 0))
			     (t (aref color-table (round (* last-step (/ d1 d)))))))))
	       color-table))))))))
