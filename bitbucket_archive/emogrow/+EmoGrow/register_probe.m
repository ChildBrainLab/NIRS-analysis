function raw = register_probe( raw )
% This function performs probe registration to the Colin27 brain atlas

job = nirs.modules.RegisterProbe();

job.optode_reference_distance(end+1,:) = cell2table({'Source-0001','FC5',0});
job.optode_reference_distance(end+1,:) = cell2table({'Source-0002','F5',0});
job.optode_reference_distance(end+1,:) = cell2table({'Source-0003','AF3',0});
job.optode_reference_distance(end+1,:) = cell2table({'Source-0004','Fp1',0});
job.optode_reference_distance(end+1,:) = cell2table({'Source-0005','Fp2',0});
job.optode_reference_distance(end+1,:) = cell2table({'Source-0006','AF4',0});
job.optode_reference_distance(end+1,:) = cell2table({'Source-0007','F6',0});
job.optode_reference_distance(end+1,:) = cell2table({'Source-0008','FC6',0});
job.optode_reference_distance(end+1,:) = cell2table({'Detector-0001','F7',0});
job.optode_reference_distance(end+1,:) = cell2table({'Detector-0002','AF7',0});
job.optode_reference_distance(end+1,:) = cell2table({'Detector-0003','AF8',0});
job.optode_reference_distance(end+1,:) = cell2table({'Detector-0004','F8',0});

job.source_detector_distance = 3;
job.units = 'cm';

raw = job.run( raw );

end