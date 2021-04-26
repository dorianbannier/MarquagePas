# MarquagePas.m: automatic tagging of gait events

MarquagePas.m is a matlab script allowing to tag automatically the foot off and the foot strike in all the C3D files present in a specified folder.

It is actually under development.

Currently, the script place the gait events on the base of the heel markers (LHEE, RHEE).

By default: 

- it shows systematically a graphic of the variation of each marker in time in order to verify that the scripts correctly place the foot off and foot strike. This can be skipped by setting the **montrerGraphique** parameter to 0.
- it marks general events: aller, demi-tour, retour.  This can be skipped by setting the **marquagePhaseMarche** parameter to 0.