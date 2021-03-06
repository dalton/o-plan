;;; File: island-rescue-use-example.tf
;;; Contains: TF for Pacifica-style evacuations
;;; Concept: Glen A. Reece (DAI, Edinburgh) and Austin Tate (AIAI)
;;;          12th December 1992.
;;; Method: (evac_status, etc) Jeff Dalton.
;;; Created: Jeff Dalton, 24 Sep 94
;;; Updated: Wed May 14 03:35:02 1997 by Jeff Dalton

;;; This version is used with tasks constructed for Web demos.

;;; N.B. Requires an O-Plan version >= 3.1.

;;; Island-rescue is a Pacifica domain, but goes about things differently.
;;; Some things are simplified.  E.g. we don't check what country a city
;;; is in before driving to it; we don't model the locations of the ground
;;; transports; and road transportation isn't broken down into drive, load, 
;;; and unload steps.  OTOH, we have time_windows and track the number
;;; of evacuees at each city.

;;; A City contains a particular number of people to be evacuated.
;;; GTs have a capacity, so more than one trip to a city may be needed.
;;; The number still to be moved is tracked using techniques developed
;;; for the Missionaries and Cannibals problem.  This involves working
;;; backwards from the goal.

;;; types ground_transport = (GT1 GT2);

types air_transport    = (C5 B707),
      country          = (Pacifica Hawaii_USA),
      location         = (Abyss Barnacle Calypso Delta Honolulu),
      city             = (Abyss Barnacle Calypso Delta),
      air_base         = (Delta Honolulu);

always {country Abyss} = Pacifica,
       {country Barnacle} = Pacifica,
       {country Calypso} = Pacifica,
       {country Delta} = Pacifica,
       {country Honolulu} = Hawaii_USA,
       {evac_point Delta};   ;;; the evacuation point in Pacifica


;;; Road_transport and people-counting

;;; Variables that refer to evac_status values are marked e_ for effect,
;;; c_ for condition.  The schema must be invoked "for effects".
;;; All e_ variables must be bound by the time the schema is selected.
;;; The c_ values are then computed from the e_ values without
;;; introducing any PSVs.  OTOH, ?gt does become a PSV.

schema road_transport;
  vars ?from     = ?{type city},
       ?to       = ?{type air_base},
       ?gt       = ?{type ground_transport},
       ?e_left   = ?{satisfies numberp},
       ?e_safe   = ?{satisfies numberp},
       ?c_left   = ?{satisfies numberp},
       ?c_safe   = ?{satisfies numberp},
       ?capacity = ?{satisfies numberp},
       ?take     = ?{satisfies numberp};
  only_use_for_effects {evac_status ?from} = {?e_left ?e_safe};
  nodes 1 action {drive ?take in ?gt from ?from},
        2 dummy;
  conditions only_use_if {evac_point ?to},
             only_use_if {gt_capacity ?capacity},
             compute {transport_step ?capacity ?e_left ?e_safe}
                        = {?c_left ?c_safe},
             compute {- ?e_safe ?c_safe} = ?take,
             achieve {evac_status ?from} = {?c_left ?c_safe} at 2;
  use ?gt across 1;
  time_windows duration 1 = 3 hours .. 4 hours;
end_schema;

;;; It makes a huge difference (1 April 1996) to have the time window
;;; in road_transport rather than in drive when a "use" constraint
;;; is used, but not when we use "supervised".  The huge difference
;;; is 171 AM cycles, 46 poisons vs 1548 cycles, 365 poisons.

;;; But it also works (just as well) to have both the time window
;;; and the "use" constraint in "drive".  (See island-use-example-2.)

;;; A primitive
schema drive;
  vars ?from     = ?{type city},
       ?take     = ?{satisfies numberp},
       ?gt       = ?{type ground_transport};
  expands {drive ?take in ?gt from ?from};
end_schema;

;;; {evac_status <city>} = {<# left at city> <# safe at evac pt>}

;;; Suppose we have oufe {evac_status A} = {0 100}, with capacity = 10.
;;; Well, we can do that if we can get {evac_status A} = {10 90}.  So
;;; we'll post {10 90} as an achieve.  The next road_transport activation
;;; will post {evac_status A} = {20 80} as an achieve, and so on until
;;; we reach {evac_status A} = {100 0} which is true initially.  Each
;;; step from an oufe to the required achieve is computed by the
;;; transport_step function below.

language lisp;

  (defun transport_step (capacity e_left e_safe) ; -> (c_left c_safe)
    (let ((take (min e_safe capacity)))
      (list (+ e_left take)
            (- e_safe take))))

end_language;


;;; Final steps

schema safe_at_delta;
  expands {safe_at Delta};
  only_use_for_effects {safe_at Delta};
  conditions unsupervised {evac_status Abyss   } = {0 ??},
             unsupervised {evac_status Barnacle} = {0 ??},
             unsupervised {evac_status Calypso } = {0 ??};
end_schema; 

schema safe_at_hawaii;
  expands {safe_at Hawaii};
  only_use_for_effects {safe_at Hawaii};
  local_vars ?ground_evac_pt = ?{type air_base};
  nodes sequential
         1 action {fly_empty B707 Honolulu ?ground_evac_pt},
         2 action {fly_passengers B707 ?ground_evac_pt Honolulu}
        end_sequential;
  conditions only_use_if {evac_point ?ground_evac_pt},
             achieve {safe_at ?ground_evac_pt} at 2;
end_schema;


;;; Simple air transport primitives

schema fly_empty;
  vars ?plane = ?{type air_transport},
       ?to    = ?{type air_base},
       ?from  = ?{type air_base};
  expands {fly_empty ?plane ?from ?to};
  time_windows duration self = 2 hours .. 3 hours;
end_schema;

schema fly_passengers;
  vars ?plane = ?{type air_transport},
       ?to    = ?{type air_base},
       ?from  = ?{type air_base};
  expands {fly_passengers ?plane ?from ?to};
  time_windows duration self = 2 hours .. 3 hours;
end_schema;


;;; End

