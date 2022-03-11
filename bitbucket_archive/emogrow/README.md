# EmoGrow
## About
This repository contains the scripts and helper functions for working with the R01 EmoGrow dataset. This is primarily intended for generic data access issues rather than data analysis. All functions are in the EmoGrow namespace, meaning they can be accessed using the EmoGrow prefix (e.g., the load_nirs function is accessed by EmoGrow.load_nirs).

## List of functions

* **add_dbdos_performance** - Load puzzle performance data for DB-DOS

* **add_dbdos_synchrony** - Load behavioral synchony codes for DB-DOS

* **add_demographics** - Load demographic/IQ/CBQ/MAP data from excel files and merge into the NIRS data for analyses

* **fix_stims** - Repair the stimulus/condition information in the NIRS data and remove any bad scans

* **load_nirs** - Loads the NIRS data for specific tasks and visits based on the tracking form

* **load_nirs_all** - Loads all of the NIRS data (_slow_) without the tracking form (debugging only)

* **register_probe** - Performs registration of the probe to the Colin template

* **draw_hyperscan_3D** - Renders hyperscanning results on 3D brains

## Usage
``` matlab
% First navigate to "Scan Data" folder containing subject NIRS folders
raw = EmoGrow.load_nirs('Monkey','V1'); % Load raw data for visit 1 Monkey task
raw = EmoGrow.fix_stims(raw);           % Fix stimulus information
raw = EmoGrow.register_probe(raw);      % Register 3D probe

% Now navigate to parent directory so it can find the questionnaire data
raw = EmoGrow.add_demographics(raw);    % Load demographic info into NIRS files

% If processing DB-DOS, you can also load puzzle performance and behavioral synchrony codes
raw = EmoGrow.add_dbdos_performance(raw);
raw = EmoGrow.add_dbdos_synchrony(raw);
```
