# Email Classification Label Taxonomy

## Level-1 Labels (Source Category)
These labels identify the source of the email:

- **Administration / Office**: Emails from charusat.ac.in domain with admin/office keywords (e.g., exam cell, fees, timetable, office order).
- **Faculty / Academic Staff**: Emails from charusat.ac.in domain not matching admin/office keywords.
- **Student / Club**: Emails from charusat.edu.in domain.
- **External Course Provider**: Emails from known external course domains (e.g., nptel.iitm.ac.in, coursera.org).
- **Misc / External**: All other emails.

## Level-2 Labels (Topic/Intent)
These labels identify the topic or intent of the email, using rule-based and model-based approaches. Examples include:

- **Fee Payment**
- **Exam Schedule**
- **Course Enrollment**
- **Event Announcement**
- **Newsletter**
- **General Communication**

Level-2 labels are assigned using a combination of keyword rules, sender domain logic, and supervised ML models. See `step4_label_topic/level2_rules.py` for implementation details.
LEVEL-0 → Preprocessing Layer

Purpose: Improve embeddings + models.

Remove disclaimers

Remove signatures

Remove forwarded chain metadata

Extract the main meaningful body

Normalize whitespace

Lowercase

This dramatically improves similarity scores.

LEVEL-1 → Source Category (Soft Routing Layer)

NOT a hard filter.
This layer identifies who the email is from, not what it is about.

Level-1 Categories
Label	Meaning
External Course Provider	NPTEL, Coursera, Cisco, AWS Academy, etc.
University Automation	E-Gov portal, fee notices, attendance system, exam system mails
Faculty / Academic Staff	All @charusat.ac.in senders
Student / Club	All @charusat.edu.in senders (students, IEEE clubs, Cloud Club, etc.)
Misc / External Sender	Ads, newsletters, vendors, unknown
Important rule:

Level-1 is a hint, not a restriction.
It should NEVER disallow or block Level-2 labels.

Instead, it only provides weighting biases later.

LEVEL-2 → Topic Classification (Hard Semantic Labeling)

This is the true heart of your system.
These 9 labels must be allowed for every Level-1 category.

Level-2 Categories
Label	When to use
Timetable / Schedule Update	Class changes, timetable, rescheduling
Exam Notifications	Exam dates, hall tickets, seating plans
Assignment or Submission	SGP reports, project submissions, assignments
Certification / Courses	AWS, NPTEL, CISCO, MOOCs, course enrollments
Internship / Placement Opportunities	Jobs, internships, CDPC mails
Events / Hackathons	Workshops, seminars, hackathons, club events
Important Announcements	Urgent circulars, policy changes, required actions
Administrative / Fees / Counselling	Fees, counselling, hostel, leave rules
General Information / Misc	Anything that doesn't fit above
Rules:

Level-2 classification uses embeddings + keywords + weighting from Level-1.

No hard restrictions based on Level-1.

If embedding confidence is low → send to Level-2 fallback (LLM).

LEVEL-3 → Urgency Classification Layer

This is independent of Level-2.

Urgency	Meaning
Critical	deadline today/tomorrow; missing this causes penalties
High	deadline within 2–3 days; important to act
Medium	relevant academic info but no action required immediately
Low	optional: events, clubs, workshops
None	newsletters, ads, routine info

This is derived from:

dates inside email

deadline keywords

requirement verbs

student action needed

LEVEL-4 → Priority Score (Optional Layer for Your App)

This uses Level-2 + Level-3:

priority = urgency_weight + topic_weight + sender_weight


Example:

Exam Notification + Critical = Highest priority

Administrative + Medium = Moderate priority

Events + Low = Low priority

Misc + None = Ignore