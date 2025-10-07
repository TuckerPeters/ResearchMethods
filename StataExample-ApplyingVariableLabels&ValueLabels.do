*Originally created on: 9/3/09; last updated 10/1/25
*Created by: Paul Manna; updated by Paul Manna
*File name: StataExample-ApplyingVariableLabels&ValueLabels.do
*File purpose: To demonstrate applying variable and value labels.
*See govmoddata_v10widebs.xls for coding notes.


*I'm using the data file boardchiefselect.dta


*Applying variable labels to each variable

label variable statename "State name"
label variable stateabbrev "State abbreviation"
label variable year "Year"
label variable bs "State board selection method"
label variable cs "State chief selection method"


*Applying value labels to the values associated with each variable
*I'm doing this because my measures are nominal. I would also do it if they were ordinal.
*I would NOT do this for measures that are interval or ratio.

label define boardselect /*
*/ 100 "No board" /*
*/ 101 "Board elected" /*
*/ 102 "Governor appoints all board members" /*
*/ 103 "Legislature appoints all board members" /*
*/ 104 "Governor appoints some board members" /*
*/ 105 "Other method to select board"
label values bs boardselect

label define chiefselect /*
*/ 1 "Chief elected" /*
*/ 2 "Govenor appoints chief" /*
*/ 3 "State board appoints chief"
label values cs chiefselect


*Don't forget to save the changes!
save boardchiefselect.dta, replace
