
%% STM LEARNINGBACH 2018 - PREPROCESSING


%% Maxfilter


%OBS! before running maxfilter you need to close matlab, open the terminal and write: 'use anaconda', then open matlab and run maxfilter script

maxfilter_path = '/neuro/bin/util/maxfilter';
project = 'MINDLAB2018_MEG-LearningBach-MemoryInformation';
maxDir = '/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc'; %output path
movement_comp = 0; %1 = yes; 0 = no


path = '/raw/sorted/MINDLAB2018_MEG-LearningBach-MemoryInformation'; %path with all the subjects folders
jj = dir([path '/0*']); %list all the folders starting with '0' in order to avoid hidden files
for ii = 1:length(jj) %over subjects (after SUBJ0013 included since we have made a few changes after the original subjects)
    cart = [jj(ii).folder '/' jj(ii).name]; %create a path that combines the folder name and the file name
    pnana = dir([cart '/2*']); %search for folders starting with '2'
    for pp = 1:length(pnana) %loop to explore ad analyze all the folders inside the path above
        cart2 = [pnana(1).folder '/' pnana(pp).name];
        pr = dir([cart2 '/ME*']); %looks for meg folder
        if ~isempty(pr) %if pr is not empty, proceed with subfolders inside the meg path
            clear pnunu1
            pnunu1(1) = {dir([pr(1).folder '/' pr(1).name '/00*oldnewsimple'])};                              
            for dd = 1:length(pnunu1)
                if ~isempty(pnunu1{dd}) %if you have the .fif file
                    pnunu = pnunu1{dd};
                    fpath = dir([pnunu(1).folder '/' pnunu(1).name '/files/*.fif']); % looks for .fif file
                    rawName = ([fpath.folder '/' fpath.name]); %assigns the final path of the .fif file to the rawName path used in the maxfilter command
                    maxfName = ['SUBJ' jj(ii).name '_' fpath.name(1:end-4)]; %define the output name of the maxfilter processing
                    if movement_comp == 1
                        %movement compensation
                        cmd = ['submit_to_cluster -q maxfilter.q -n 4 -p ' ,project, ' "',maxfilter_path,' -f ',[rawName],' -o ' [maxDir '/' maxfName '_tsssdsm.fif'] ' -st 4 -corr 0.98 -movecomp -ds 4 ',' -format float -v | tee ' [maxDir '/log_files/' maxfName '_tsssdsm.log"']];
                    else %no movement compensation (to be used if HPI coils did not work properly)
                        cmd = ['submit_to_cluster -q maxfilter.q -n 4 -p ' ,project, ' "',maxfilter_path,' -f ',[rawName],' -o ' [maxDir '/' maxfName '_tsssdsm.fif'] ' -st 4 -corr 0.98 -ds 4 ',' -format float -v | tee ' [maxDir '/log_files/' maxfName '_tsssdsm.log"']];
                    end
                    system(cmd);
                end
            end
        end
    end
end




%% Starting up OSL

%OBS! run this before converting the .fif files into SPM objects

addpath('/projects/MINDLAB2017_MEG-LearningBach/scripts/osl/osl-core'); %adds the path to OSL functions
osl_startup %starts the osl package


%% Converting the .fif files into SPM objects

%OBS! remember to run 'starting up OSL' first

%setting up the cluster
addpath('/projects/MINDLAB2017_MEG-LearningBach/scripts/Cluster_ParallelComputing') %add the path to the function that submits the jobs to the cluster
clusterconfig('scheduler', 'cluster');
clusterconfig('long_running', 1); %there are different queues for the cluster depending on the number and length of the jobs you want to submit 
clusterconfig('slot', 1); %slot in the queu

%% conversion to SPM objects

fif_list = dir('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/*.fif'); %path to SPM objects

for ii = 26 %:length(fif_list) %over the .fif files
    S = []; %structure 'S'                   
    S.dataset = [fif_list(ii).folder '/' fif_list(ii).name];
    D = spm_eeg_convert(S);
%     D = job2cluster(@cluster_spmobject, S); %actual function for conversion
end

%% Removing bad segments using OSLVIEW

%checks data for potential bad segments (periods)
%marking is done by right-clicking in the proximity of the event and click on 'mark event'
%a first click (green dashed label) marks the beginning of a bad period
%a second click indicates the end of a bad period (red)
%this will mean that we are not using about half of the data, but with such bad artefacts this is the best we can do
%we can still obtain good results with what remains
%NB: Push the disk button to save to disk (no prefix will be added, same name is kept)

%OBS! remember to check for bad segments of the signal both at 'megplanar' and 'megmag' channels (you can change the channels in the OSLVIEW interface)

%OBS! remember to mark the trial within the bad segments as 'badtrials' and use the label for removing them from the Averaging (after Epoching) 

spm_list = dir('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/spmeeg*.mat'); %path to SPM objects

for ii = 26%:length(spm_list) %over experimental blocks %OBS!
    D = spm_eeg_load([spm_list(ii).folder '/' spm_list(ii).name]);
    D = oslview(D);
    D.save(); %save the selected bad segments and/or channels in OSLVIEW
    disp(ii)
end

%% AFRICA denoising (part I)

%setting up the cluster
clusterconfig('scheduler', 'cluster');
clusterconfig('long_running', 1); %there are different queues for the cluster depending on the number and length of the jobs you want to submit 
clusterconfig('slot', 1); %slot in the queu
addpath('/projects/MINDLAB2017_MEG-LearningBach/scripts/Cluster_ParallelComputing') %add the path to the function that submits the jobs to the cluster

%%

%ICA calculation
spm_list = dir('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/spmeeg*.mat');

for ii = 2:length(spm_list) %OBS!
    S = [];
    D = spm_eeg_load([spm_list(ii).folder '/' spm_list(ii).name]);
    S.D = D;
    
    jobid = job2cluster(@cluster_africa,S);
%   D = osl_africa(D,'do_ica',true,'do_ident',false,'do_remove',false,'used_maxfilter',true); 
%   D.save();
end

%% AFRICA denoising (part II)

% v = [11 12 19 32];
%visual inspection and removal of artifacted components
%look for EOG and ECG channels (usually the most correlated ones, but check a few more just in case)
spm_list = dir('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/spmeeg*.mat');

for ii = 14:length(spm_list) %OBS!%38:41
    D = spm_eeg_load([spm_list(ii).folder '/' spm_list(ii).name]);
    D = osl_africa(D,'do_ident','manual','do_remove',false,'artefact_channels',{'EOG','ECG'});
    %hacking the function to manage to get around the OUT OF MEMORY problem..
    S = [];
    S.D = D;
    jobid = job2cluster(@cluster_rembadcomp,S);
%   D.save();
    disp(ii)
end


%% Epoching: one epoch per old/new excerpt (baseline = (-)100ms)

epoch_l = 2; %1 = long epoch including the first sound repeated three times, the distractor and then the target sound; 2 = short epoch, including only the target sound

if epoch_l == 1
    prefix_tobeadded = 'e'; %adds this prefix to epoched files
    evvall = 175;
    lengthev = 12;
elseif epoch_l == 2
    prefix_tobeadded = 'es'; %adds this prefix to epoched files
    evvall = 174;
    lengthev = 3.4;
end
spm_list = dir('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/spmeeg*.mat');

for ii = 13%:length(spm_list) %over .mat files
    D = spm_eeg_load([spm_list(ii).folder '/' spm_list(ii).name]); %load spm_list .mat files
    D = D.montage('switch',0);
    dummy = D.fname; %OBS! D.fname does not work, so we need to use a 'dummy' variable instead
    %if strcmp(dummy(22:26), 'speed') %checks whether characters 22 to 26 are equal to 'speed'; the loop continues if this is true (1) and it stops if this is false (0)
    events = D.events; %look for triggers
    
    %takes the correct triggers sent during the recording
    clear trigcor
    count_evval = 0; %???
    for ieve = 1:length(events) %over triggers
        if strcmp(events(ieve).type,'STI101_up') %only triggers at the beginning of each stimuli
            %if strcmp('aud',spm_list(ii).name(17:19)) || strcmp('vis',spm_list(ii).name(17:19))
                %if events(ieve).value ~= 103 && events(ieve).value ~= 104 && events(ieve).value ~= 128 && events(ieve).value ~= 8 && events(ieve).value ~= 132 && events(ieve).value ~= 48 && events(ieve).value ~= 32 && events(ieve).value ~= 64 %discard 104 and 128 for random triggers
                if events(ieve).value == evvall %10 and 50 are old and new in recogminor (block 3), while 11 and 21 are old and new in blocks 4 and 5 (aud and vis)
                    count_evval = count_evval + 1;
                    trigcor(count_evval,1) = events(ieve).time + 0.010; %this takes the correct triggers and add 10ms of delay of the sound travelling into the tubes
                    %variable with all the triggers we need
                end
            %end
        end
    end
    trl_sam = zeros(length(trigcor),3); %prepare the samples matrix with 0's in all its cells
    trl_sec = zeros(length(trigcor),3); %prepare the seconds matrix with 0's in all its cells
    %deftrig = zeros(length(trigcor),1); %this is not useful
    for k = 1:length(trigcor) %over selected triggers
        %deftrig(k,1) = 0.012 + trigcor(k,1); %adding a 0.012 seconds delay to the triggers sent during the experiment (this delay was due to technical reasons related to the stimuli)
        trl_sec(k,1) = trigcor(k,1) - 0.100; %beginning time-window epoch in s (please note that we computed this operation two times, obtaining two slightly different pre-stimulus times.
        %this was done because for some computations was convenient to have a slightly longer pre-stimulus time
        %remove 1000ms of baseline
        trl_sec(k,2) = trigcor(k,1) + lengthev; %end time-window epoch in seconds
        trl_sec(k,3) = trl_sec(k,2) - trl_sec(k,1); %range time-windows in seconds
        trl_sam(k,1) = round(trl_sec(k,1) * D.fsample) + 1; %beginning time-window epoch in samples %250Hz per second
        trl_sam(k,2) = round(trl_sec(k,2) * D.fsample) + 1; %end time-window epoch in samples
        trl_sam(k,3) = -25; %sample before the onset of the stimulus (corresponds to 0.100ms)
    end
    dif = trl_sam(:,2) - trl_sam(:, 1); %difference between the end and the beginning of each sample (just to make sure that everything is fine)
    if ~all(dif == dif(1)) %checking if every element of the vector are the same (i.e. the length of the trials is the same; we may have 1 sample of difference sometimes because of different rounding operations..)
        trl_sam(:,2) = trl_sam(:,1) + dif(1);
    end
    %creates the epochinfo structure that is required for the source reconstruction later
    epochinfo.trl = trl_sam;
    epochinfo.time_continuous = D.time;
    %switch the montage to 0 because for some reason OSL people prefer to do the epoching with the not denoised data
    D = D.montage('switch',0);
    %build structure for spm_eeg_epochs
    S = [];
    S.D = D;
    S.trl = trl_sam;
    S.prefix = prefix_tobeadded;
    D = spm_eeg_epochs(S);
    %store the epochinfo structure inside the D object
    D.epochinfo = epochinfo;
    D.save();
    %take bad segments registered in OSLVIEW and check if they overlap with the trials. if so, it gives the number of overlapped trials that will be removed later
    count = 0;
    Bad_trials = zeros(length(trl_sec),1);
    for kkk = 1:length(events) %over events
        if strcmp(events(kkk).type,'artefact_OSL')
            for k = 1:length(trl_sec) %over trials
                if events(kkk).time - trl_sec(k,2) < 0 %if end of trial is > than beginning of artifact
                    if trl_sec(k,1) < (events(kkk).time + events(kkk).duration) %if beginning of trial is < than end of artifact
                        Bad_trials(k,1) = 1; %it is a bad trial (stored here)
                        count = count + 1;
                    end
                end
            end
        end
    end
    %if bad trials were detected, their indices are stored within D.badtrials field
    disp(spm_list(ii).name);
    if count == 0
        disp('there are no bad trials marked in oslview');
    else
        D = badtrials(D,find(Bad_trials),1); %get the indices of the badtrials marked as '1' (that means bad)
        %         D = conditions(D,find(Bad_trials),1); %get the indices of the badtrials marked as '1' (that means bad)
        epochinfo = D.epochinfo;
        xcv = find(Bad_trials == 1);
        %this should be done only later.. in any case.. not a problem..
        for jhk = 1:length(xcv)
            D = D.conditions(xcv(jhk),'Bad');
            epochinfo.conditionlabels(xcv(jhk)) = {'Bad'};
            disp([num2str(ii) ' - ' num2str(jhk) ' / ' num2str(length(xcv))])
        end
        D.epochinfo = epochinfo;
        D.save(); %saving on disk
        disp('bad trials are ')
        length(D.badtrials)
    end
    D.save();
    disp(ii)
end

%% Defining the conditions - All blocks

epoch_l = 2; %1 = long epoch including the first sound repeated three times, the distractor and then the target sound; 2 = short epoch, including only the target sound

xlsx_dir_behav = '/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Virginia/ONS_logs'; %dir to MEG behavioral results (.xlsx files)
if epoch_l == 1
    epoch_list = dir('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/e*.mat'); %dir to epoched files
    extr = 14:16;
else
    epoch_list = dir('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/esspm*.mat'); %dir to epoched files
    extr = 15:17;
end
for ii = 13%:length(epoch_list) %over epoched data
    if ii ~= 12
        D = spm_eeg_load([epoch_list(ii).folder '/' epoch_list(ii).name]);
        fname = D.fname;
        [~,~,raw_recog] = xlsread([xlsx_dir_behav '/' fname(extr) '.xlsx']); %excel files
        %picking the current block
        for k = 1:length(D.trialonset)
            if strcmp(raw_recog{(k + 1),3}(1:2),'ol') %old
                D = D.conditions(k,'Old'); %assign old correct
            elseif strcmp(raw_recog{(k + 1),3}(1:2),'ne') %new
                D = D.conditions(k,'New'); %otherwise assign new correct
            end
        end
        %this is for every block
        if ~isempty(D.badtrials) %overwriting badtrials (if any) on condition labels
            BadTrials = D.badtrials;
            for badcount = 1:length(BadTrials) %over bad trials
                D = D.conditions(BadTrials(badcount),'Bad_trial');
            end
        end
        D = D.montage('switch',1);
        D.epochinfo.conditionlabels = D.conditions; %to add for later use in the source reconstruction
        D.save(); %saving data on disk
        disp(num2str(ii))
    end
end

%% MEG behavioral statistics
% 
% %define conditions - 1 epoch for each old/new excerpt (baseline = (-)100ms)
% xlsx_dir_behav = '/scratch7/MINDLAB2021_MEG-TempSeqAges/leonardo/MEG_behavioural'; %dir to MEG behavioral results (.xlsx files)
% epoch_list = dir('/scratch7/MINDLAB2021_MEG-TempSeqAges/leonardo/after_maxfilter/es*.mat'); %dir to epoched files
% 
% %groups of partecipants
% gsubj{1} = [2,5,9,13,14,15,17,19,21,22,24,25,37,39,40,41,44,46,50,53,54,55,57,60,63,64,65,67,69,70,71,72,73,74,75,77,78]; %young
% gsubj{2} = [3,4,6,7,8,10,11,12,16,18,20,23,26,27,28,29,30,31,32,33,34,35,36,38,42,43,45,47,48,49,51,52,56,58,59,61,62,66,68,76]; %elderly
% clear EL3 YO3
% el3 = 0; yo3 = 0;
% for ii = 2:length(epoch_list) %over epoched data (starting with 2 since number 1 has a different name since I had to merge two mmn files to get it..)
%     if ~strcmp('mmn',epoch_list(ii).name(18:20)) %if the block is not the MMN block..
%         %loading SPM object (epoched data)
%         D = spm_eeg_load([epoch_list(ii).folder '/' epoch_list(ii).name]);
%         dummy = D.fname; %%% OBS!! (SUBJ0041 IS NOT AUD1 AS IN THE NAME BUT IT IS AUD2!!) HERE YOU DID MANUAL ADJUSTMENT OF VARIABLE dummy TO FIX IT..
%         %barbaric solution.. to build the name to be read for the excel files with the MEG behavioral tasks performance
%         if strcmp(dummy(18:20),'rec') || strcmp(dummy(18:20),'rac')
%             dumbloc = 'Block_3.xlsx';
%             bl = 3;
%         elseif strcmp(dummy(18:20),'aud')
%             dumbloc = 'Block_4_Auditory.xlsx';
%             bl = 4;
%         elseif strcmp(dummy(18:20),'vis')
%             dumbloc = 'Block_5_Visual.xlsx';
%             bl = 5;        
%         end
%         dumls = ['Subj_' dummy(13:16) '_' dumbloc];
%         [~,~,raw_recog] = xlsread([xlsx_dir_behav '/' dumls]); %excel files
%         %picking the current block
%         if bl == 3 %block 3
%             nr = 0; oc = 0; oi = 0; n1c = 0; n1i = 0; n3c = 0; n3i = 0;
%             ocrt = []; oirt = []; n1crt = []; n1irt = []; n3crt = []; n3irt = [];
%             for k = 1:length(D.trialonset)
%                 if raw_recog{(k + 1),3} == 0 %if there was no response
%                     nr = nr + 1;
%                 elseif strcmp(raw_recog{(k + 1),2}(8:9),'ol') && raw_recog{(k + 1),3} == 1 %old correct
%                     oc = oc + 1; ocrt(oc) = raw_recog{(k + 1),4};
%                 elseif strcmp(raw_recog{(k + 1),2}(8:9),'ol') && raw_recog{(k + 1),3} == 2 %old incorrect
%                     oi = oi + 1; oirt(oi) = raw_recog{(k + 1),4};
%                 elseif strcmp(raw_recog{(k + 1),2}(14:15),'t1') && raw_recog{(k + 1),3} == 2 %new t1 correct
%                     n1c = n1c + 1; n1crt(n1c) = raw_recog{(k + 1),4};
%                 elseif strcmp(raw_recog{(k + 1),2}(14:15),'t1') && raw_recog{(k + 1),3} == 1 %new t1 incorrect
%                     n1i = n1i + 1; n1irt(n1i) = raw_recog{(k + 1),4};
%                 elseif strcmp(raw_recog{(k + 1),2}(14:15),'t3') && raw_recog{(k + 1),3} == 2 %new t3 correct
%                     n3c = n3c + 1; n3crt(n3c) = raw_recog{(k + 1),4};
%                 elseif strcmp(raw_recog{(k + 1),2}(14:15),'t3') && raw_recog{(k + 1),3} == 1 %new t3 incorrect
%                     n3i = n3i + 1; n3irt(n3i) = raw_recog{(k + 1),4};
%                 end
%             end
%             if sum(double(str2num(dummy(13:16))==gsubj{2})) == 1
%                 el3 = el3 + 1;
%                 EL3(el3,1) = nr;
%                 EL3(el3,2) = oc;
%                 EL3(el3,3) = mean(ocrt);
%                 EL3(el3,4) = oi;
%                 EL3(el3,5) = mean(oirt);
%                 EL3(el3,6) = n1c;
%                 EL3(el3,7) = mean(n1crt);
%                 EL3(el3,8) = n1i;
%                 EL3(el3,9) = mean(n1irt);
%                 EL3(el3,10) = n3c;
%                 EL3(el3,11) = mean(n3crt);
%                 EL3(el3,12) = n3i;
%                 EL3(el3,13) = mean(n3irt);            
%             elseif sum(double(str2num(dummy(13:16))==gsubj{1})) == 1
%                 yo3 = yo3 + 1;
%                 YO3(yo3,1) = nr;
%                 YO3(yo3,2) = oc;
%                 YO3(yo3,3) = mean(ocrt);
%                 YO3(yo3,4) = oi;
%                 YO3(yo3,5) = mean(oirt);
%                 YO3(yo3,6) = n1c;
%                 YO3(yo3,7) = mean(n1crt);
%                 YO3(yo3,8) = n1i;
%                 YO3(yo3,9) = mean(n1irt);
%                 YO3(yo3,10) = n3c;
%                 YO3(yo3,11) = mean(n3crt);
%                 YO3(yo3,12) = n3i;
%                 YO3(yo3,13) = mean(n3irt);  
%             end
%             
%         end        
%     end
%     disp(num2str(ii))
% end


%% 

%% Averaging and Combining planar gradiometers

%settings for cluster (parallel computing)
addpath('/projects/MINDLAB2017_MEG-LearningBach/scripts/Cluster_ParallelComputing') %add the path to the function that submits the jobs to the cluster
clusterconfig('scheduler', 'cluster'); %set automatically the long run queue
clusterconfig('long_running', 1); %set automatically the long run queue
clusterconfig('slot', 1); %set manually the job cluster slots
% between 1 and 12 (n x 8gb of ram)

%% averaging

epoch_l = 2; %1 = long epoch including the first sound repeated three times, the distractor and then the target sound; 2 = short epoch, including only the target sound

output_prefix_to_be_set = 'm';
if epoch_l == 1
    epoch_list = dir ('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/e*mat'); %dir to epoched files (encoding)
else
    epoch_list = dir('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/esspm*.mat'); %dir to epoched files
end
v = [1:length(epoch_list)];
for ii = 13%:length(v)%1:length(epoch_list) %over epoched files
    if ii ~= 12
        input = [];
        input.D = [epoch_list(v(ii)).folder '/' epoch_list(v(ii)).name];
        input.prefix = output_prefix_to_be_set;
        jobid = job2cluster(@sensor_average, input); % this is the command for send the job to the cluster, in the brackets you can find the name on the function to run (afeter the @) and the variable for the input (in this case input)
        % look the script for more details about the function work
    end
end

%% combining planar gradiometers

epoch_l = 2; %1 = long epoch including the first sound repeated three times, the distractor and then the target sound; 2 = short epoch, including only the target sound

if epoch_l == 1
    average_list = dir ('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/me*mat'); %dir to epoched files (encoding)
else
    average_list = dir('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/messpm*.mat'); %dir to epoched files
end
v = [1:length(average_list)];
for ii = 12%:length(v)%1:length(average_list) %over files
    input = [];
    input.D = [average_list(v(ii)).folder '/' average_list(v(ii)).name];
    D = spm_eeg_load(input.D);
    D = D.montage('switch',1);
    D.save();
    jobid = job2cluster(@combining_planar_cluster, input); % this is the command for send the job to the cluster, in the brackets you can find the name on the function to run (afeter the @) and the variable for the input (in this case input)
end

%% LBPD_startup_D

pathl = '/projects/MINDLAB2017_MEG-LearningBach/scripts/Leonardo_FunctionsPhD'; %path to stored functions
addpath(pathl);
LBPD_startup_D(pathl);
addpath('/projects/MINDLAB2017_MEG-LearningBach/scripts/Cluster_ParallelComputing') %add the path where is the function for submit the jobs to the server

%% Extracting MEG sensor data

epoch_l = 2; %1 = long epoch including the first sound repeated three times, the distractor and then the target sound; 2 = short epoch, including only the target sound
% channels_plot = 13; %13;95;;9; %95, 13, 15, 11, 141, 101, 9 % empty for plotting single channels; otherwise number(s) of channels to be averaged and plotted (e.g. [13] or [13 18])
channels_plot = []; % empty for plotting single channels; otherwise number(s) of channels to be averaged and plotted (e.g. [13] or [13 18])
subj = []; %[gsubj{2}(34)]; %empty for all subjects; numbers of subjects with regards to the list indexed here if you want specific subjects
% subj = [1:11 13:27]; %[gsubj{2}(34)]; %empty for all subjects; numbers of subjects with regards to the list indexed here if you want specific subjects

% subj = [2,5,9,13,14,15,17,19,21,22,24,25,37,39,40,41,44,46,50,53,54,55,57,60,63,64,65,67,69,70,71,72,73,74,75,77,78]; %young
% subj = [3,4,6,7,8,10,11,12,16,18,20,23,26,27,28,29,30,31,32,33,34,35,36,38,42,43,45,47,48,49,51,52,56,58,59,61,62,66,68,76]; %elderly

%1321 1411
waveform_singlechannels_label = 1; %1 to plot individual channels
save_data = 0; %1 to save the data on disk
load_data = 1; %set 1 if you want to load the data instead of extracting it from SPM objects
% v = [1]; %subjects
%bad 8,9 and a bit 6 (recogminor)

S = [];
%computing data
S.conditions = {'Old','New'};
if epoch_l == 1
    list = dir ('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/Pmesp*_tsssdsm.mat'); %dir to epoched files (encoding)
    S.x_lim_temp_wave = [9 11.5]; %limits for time (in secs) (E.g. [-0.1 3.4])
else
    list = dir ('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/Pmesspm*_tsssdsm.mat'); %dir to epoched files (encoding)
    S.x_lim_temp_wave = []; %limits for time (in secs) (E.g. [-0.1 3.4])
end
S.y_lim_ampl_wave = []; %limit for amplitude (E.g. [0 120] magnetometes, [0 6] gradiometers)
if isempty(subj)
    v = 1:length(list); %subjects
else
    v = subj;
%     S.y_lim_ampl_wave = []; %limit for amplitude (E.g. [0 120] magnetometes, [0 6] gradiometers)
end
if ~exist('chanlabels','var')
    load('/scratch7/MINDLAB2020_MEG-AuditoryPatternRecognition/leonardo/after_maxfilter/MEG_sensors/recogminor_all_conditions.mat', 'chanlabels')
end
outdir = '/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/MEG_sensors'; %path to write output in
S.outdir = outdir;
S.data = [];
if load_data == 1 %if you already computed and saved on disk the t-tests you can load them here
    if epoch_l == 1
        load([outdir '/Block_simpleoldnew.mat'],'time_sel','data_mat','chanlabels');
    else
        load([outdir '/Block_simpleoldnew_short.mat'],'time_sel','data_mat','chanlabels');
    end
    S.data = data_mat(:,:,v,:);
    S.chanlabels = chanlabels;
    S.time_real = time_sel;
else %otherwise you can extract the data from SPM MEEG objects (one for each subject)
%     S.spm_list = cell(1,length(list));
% v = 7;
    S.spm_list = cell(1,length(v));
    for ii = 1:length(v)
        S.spm_list(ii) = {[list(v(ii)).folder '/' list(v(ii)).name]};
    end
end

S.timeextract = []; %time-points to be extracted
S.centerdata0 = 0; %1 to make data starting at 0
S.save_data = save_data; %only meaningfull if you read data from SPM objects saved on disk
if epoch_l == 1
    S.save_name_data = ['Block_simpleoldnew'];
else
    S.save_name_data = ['Block_simpleoldnew_short'];
end

%individual waveform plotting
if isempty(channels_plot)
    S.waveform_singlechannels_label = waveform_singlechannels_label; %1 to plot single channel waveforms
else
    S.waveform_singlechannels_label = 0; %1 to plot single channel waveforms
end
S.wave_plot_conditions_together = 0; %1 for plotting the average of all
S.mag_lab = 1; %1 for magnetometers; 2 for gradiometers

%averaged waveform plotting
if isempty(channels_plot)
    S.waveform_average_label = 0; %average of some channels
    S.left_mag = 95; %13 %37 (visual) %43 (visual) %199 (visual) %203 (visual) %channels for averaging
else
    S.waveform_average_label = 1; %average of some channels
    S.left_mag = channels_plot; %13 %37 (visual) %43 (visual) %199 (visual) %203 (visual) %channels for averaging
end
% S.left_mag = [2:2:204];
S.legc = 1; %set 1 for legend
% S.left_mag = 99;
S.signtp = {[]};
% S.sr = 150; %sampling rate (Hz)
S.avewave_contrast = 0; %1 to plot the contrast between conditions (averaged waveform)
S.save_label_waveaverage = 0;
S.label_plot = 'c';
%t-tests
S.t_test_for_permutations = 0;
S.cond_ttests_tobeplotted_topoplot = [1 2]; %this is for both topoplot and t-tests!! (here [1 2] means cond1 vs cond2!!!!!!!)
S.magabs = 1;

%topoplotting
S.topoplot_label = 0;
S.fieldtrip_mask = '/projects/MINDLAB2017_MEG-LearningBach/scripts/Leonardo_FunctionsPhD/External';
S.topocontr = 0;
S.topocondsing = [2]; %condition for topoplot
% S.xlim = [0.75 0.85]; %time topolot
% S.xlim = [1.1 1.2]; %time topolot
S.xlim = [3.5 4.3]; 
S.zlimmag = []; %magnetometers amplitude topoplot limits
S.zlimgrad = []; %gradiometers amplitude topoplot limits
S.colormap_spec = 0;
% x = []; x.bottom = [0 0 1]; x.botmiddle = [0 0.5 1]; x.middle = [1 1 1]; x.topmiddle = [1 1 0.5]; x.top = [1 0.95 0]; %yellow - blue
x = []; x.bottom = [0 0 0.5]; x.botmiddle = [0 0.5 1]; x.middle = [1 1 1]; x.topmiddle = [1 0 0]; x.top = [0.6 0 0]; %red - blue
S.colormap_spec_x = x;
S.topoplot_save_label = 0;

[out] = MEG_sensors_plotting_ttest_LBPD_D2(S);

%%

%% Monte-Carlo simulations (MCS)

%input information
p_thresh = 0.05; %for binarising p-values matrices..


%actual computation
%time-points to be selected
min_time_point = 26;
max_time_point = 276;
clear DATAP2 TSTAT2
outdir = '/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/MEG_sensors'; %path where t-test results are stored in
load([outdir '/Block_simpleoldnew_short_OUT_Old_vs_New.mat']);
load('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/time_short.mat');
chanlabels = OUT.chanlabels;
time_sel = OUT.time_sel;
%here gradiometers and magnetometers are always extracted but in the
%following steps only the requested channels (either magnetometers or
%gradiometers) are used
DATAP2(:,:,1) = OUT.TSTATP_mag(:,min_time_point:max_time_point);
DATAP2(:,:,2) = OUT.TSTATP_grad(:,min_time_point:max_time_point);
TSTAT2(:,:,1) = OUT.TSTAT_mag(:,min_time_point:max_time_point);
TSTAT2(:,:,2) = OUT.TSTAT_grad(:,min_time_point:max_time_point);
chanlab = chanlabels(1:2:204)';
label = zeros(length(chanlab),1); %channels label
for ii = 1:length(chanlab)
    label(ii,1) = str2double(chanlab{ii,1}(4:end));
end

%individuating positive vs negative t-values
P = DATAP2; %trick for looking only into the positive t-values
P(P < p_thresh) = 1; %binarizing p-values according to threshold
P(P < 1) = 0;
%old (pos) > new (neg)
P(TSTAT2 < 0) = 0; %deleting p-values for negative contrasts
TSTAT_mag_pos = P(:,:,1);
TSTAT_grad = P(:,:,2);
%negative vs positive p-values
P = DATAP2;
P(P < p_thresh) = 1; %binarizing p-values according to threshold
P(P < 1) = 0;
P(TSTAT2 > 0) = 0; %deleting p-values for positive contrasts
TSTAT_mag_neg = P(:,:,1);
%load a 2D approximation in a matrix of the MEG channels location (IT IS CONTAINED IN THE FUNCTIONS FOLDER THAT WE PROVIDED)
[~,~,raw_channels] = xlsread('/projects/MINDLAB2017_MEG-LearningBach/scripts/Leonardo_FunctionsPhD/External/MatrixMEGChannelLayout_With0_2.xlsx');
% reshaping data for computational purposes
S = [];
S.label = label;
S.TSTAT_mag_pos = TSTAT_mag_pos;
S.TSTAT_mag_neg = TSTAT_mag_neg;
S.TSTAT_grad = TSTAT_grad;
S.TVal = TSTAT2;
S.raw_channels = raw_channels;

[MAG_data_pos, MAG_data_neg, GRAD_data, MAG_GRAD_tval] = MEG_sensors_MCS_reshapingdata_LBPD_D(S);

%actual Monte Carlo simulations
S = [];
%actual gradiometers data
S.time = time(min_time_point:max_time_point);
S.data(:,:,:,1) = zeros(size(MAG_data_pos,1),size(MAG_data_pos,2),size(MAG_data_pos,3)); %GRAD_data;
%zeros.. if you do not want to run the function for magnetometers
S.data(:,:,:,2) = MAG_data_pos;
S.data(:,:,:,3) = zeros(size(MAG_data_pos,1),size(MAG_data_pos,2),size(MAG_data_pos,3)); %MAG_data_neg;
S.sensortype = [];
S.MAG_GRAD_tval = MAG_GRAD_tval;
S.MEGlayout = cell2mat(raw_channels);
S.permut = 1000;
S.clustmax = 1;
S.permthresh = 0.001;

[MAG_clust_pos, MAG_clust_neg, GRAD_clust] = MEG_sensors_MonteCarlosim_LBPD_D(S);


%% extracting first and last significant time-point for each channel, converting them into seconds (from time-samples) and printing it as xlsx file 

%Here you can print the statistics in tables/excel files that can be
%convenient to read. You can simply select the significant cluster number
%that you want by specifying it in the line below.
%THIS RESULTS CAN BE FOUND IN THE PAPER IN SUPPLEMENTARY MATERIALS -
%TABLE/EXCEL FILE ST2

pos_l = 2; %1 = positive contrast (old vs new); 2 = negative contrast (ne vs old)
clustnum = 7;

load('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/MEG_sensors/MCS_Short/Mag_clust_oldvsnew.mat');
if pos_l == 1
    hh = MAG_clust_pos{clustnum,3};
else
    hh = MAG_clust_neg{clustnum,3};
end

time_sel2 = time_sel(1,min_time_point:max_time_point);
clear ff2
ff2(:,1) = hh(:,1); %extracting channel names
for ii = 1:size(ff2,1)
    ff2(ii,2) = {time_sel2(hh{ii,2}(1))}; %first significant time-point
    ff2(ii,3) = {time_sel2(hh{ii,2}(end))}; %last significant time-point
end
PDn = cell2table(ff2) %converting cell to table
% writetable(PDn,['NegPos_clust1_OldvsNew.xlsx'],'Sheet',1) %saving xlsx file

%% same concept but only for three main clusters (both for positive and negative contrasts, so six in total)

pos_l = 1; %1 = positive contrast (old vs new); 2 = negative contrast (ne vs old)

load('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/MEG_sensors/MCS_Short/Mag_clust_oldvsnew.mat');
if pos_l == 1
    clustnum = [9,7,11];
    cluss = 'OldvsNew';
else
    clustnum = [5,3,7];
    cluss = 'NewvsOld';
end
for iii = 1:length(clustnum)
    if pos_l == 1
        hh = MAG_clust_pos{clustnum(iii),3};
    else
        hh = MAG_clust_neg{clustnum(iii),3};
    end
    time_sel2 = time_sel(1,min_time_point:max_time_point);
    clear ff2
    ff2(:,1) = hh(:,1); %extracting channel names
    for ii = 1:size(ff2,1)
        ff2(ii,2) = {time_sel2(hh{ii,2}(1))}; %first significant time-point
        ff2(ii,3) = {time_sel2(hh{ii,2}(end))}; %last significant time-point
    end
    PDn = cell2table(ff2) %converting cell to table
    writetable(PDn,['/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/MEG_sensors/MCS_Short/' cluss '_clust' num2str(iii) '.xlsx'],'Sheet',1) %saving xlsx file
end

%pos times and sizes: 0.53 - 0.6 (k = 47); 0.08 - 0.12 (k = 46); 0.29 - 0.34 (k = 41)
%neg times and sizes: 0.70 - 0.78 (k = 91); 0.43 - 0.53 (k = 79); 0.58 - 0.64 (k = 68)

%% Extracting MEG sensor data

pos_l = 2; %1 = positive contrast (old vs new); 2 = negative contrast (ne vs old)

load('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/MEG_sensors/MCS_Short/Mag_clust_oldvsnew.mat');
if pos_l == 1
    chosen_clust = MAG_clust_pos;
    CL = [9,7,11];
    CL2{1} = [0.53 0.60]; CL2{2} = [0.08 0.12]; CL2{3} = [0.29 0.34];
else
    chosen_clust = MAG_clust_neg;
    CL = [5,3,7];
    CL2{1} = [0.70 0.78]; CL2{2} = [0.43 0.53]; CL2{3} = [0.58 0.64];
end
for cc = 1%:length(chosen_clust)
    epoch_l = 2; %1 = long epoch including the first sound repeated three times, the distractor and then the target sound; 2 = short epoch, including only the target sound
    % channels_plot = 13; %13;95;;9; %95, 13, 15, 11, 141, 101, 9 % empty for plotting single channels; otherwise number(s) of channels to be averaged and plotted (e.g. [13] or [13 18])
    channels_plot = []; % empty for plotting single channels; otherwise number(s) of channels to be averaged and plotted (e.g. [13] or [13 18])
    subj = []; %[gsubj{2}(34)]; %empty for all subjects; numbers of subjects with regards to the list indexed here if you want specific subjects
    
    %1321 1411
    waveform_singlechannels_label = 0; %1 to plot individual channels
    save_data = 0; %1 to save the data on disk
    load_data = 1; %set 1 if you want to load the data instead of extracting it from SPM objects
    % v = [1]; %subjects
    %bad 8,9 and a bit 6 (recogminor)
    
    S = [];
    %computing data
    S.conditions = {'Old','New'};
    if epoch_l == 1
        list = dir ('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/Pmesp*_tsssdsm.mat'); %dir to epoched files (encoding)
        S.x_lim_temp_wave = [9 11.5]; %limits for time (in secs) (E.g. [-0.1 3.4])
    else
        list = dir ('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/Pmesspm*_tsssdsm.mat'); %dir to epoched files (encoding)
        S.x_lim_temp_wave = [-0.1 1.5]; %limits for time (in secs) (E.g. [-0.1 3.4])
    end
    S.y_lim_ampl_wave = [-50 200]; %limit for amplitude (E.g. [0 120] magnetometes, [0 6] gradiometers)
    if isempty(subj)
        v = 1:length(list); %subjects
    else
        v = subj;
        %     S.y_lim_ampl_wave = []; %limit for amplitude (E.g. [0 120] magnetometes, [0 6] gradiometers)
    end
    if ~exist('chanlabels','var')
        load('/scratch7/MINDLAB2020_MEG-AuditoryPatternRecognition/leonardo/after_maxfilter/MEG_sensors/recogminor_all_conditions.mat', 'chanlabels')
    end
    outdir = '/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/MEG_sensors'; %path to write output in
    S.outdir = outdir;
    S.data = [];
    if load_data == 1 %if you already computed and saved on disk the t-tests you can load them here
        if epoch_l == 1
            load([outdir '/Block_simpleoldnew.mat'],'time_sel','data_mat','chanlabels');
        else
            load([outdir '/Block_simpleoldnew_short.mat'],'time_sel','data_mat','chanlabels');
        end
        S.data = data_mat(:,:,v,:);
        S.chanlabels = chanlabels;
        S.time_real = time_sel;
    else %otherwise you can extract the data from SPM MEEG objects (one for each subject)
        %     S.spm_list = cell(1,length(list));
        % v = 7;
        S.spm_list = cell(1,length(v));
        for ii = 1:length(v)
            S.spm_list(ii) = {[list(v(ii)).folder '/' list(v(ii)).name]};
        end
    end
    
    S.timeextract = []; %time-points to be extracted
    S.centerdata0 = 0; %1 to make data starting at 0
    S.save_data = save_data; %only meaningfull if you read data from SPM objects saved on disk
    if epoch_l == 1
        S.save_name_data = ['Block_simpleoldnew'];
    else
        S.save_name_data = ['Block_simpleoldnew_short'];
    end
    
    %individual waveform plotting
    if isempty(channels_plot)
        S.waveform_singlechannels_label = waveform_singlechannels_label; %1 to plot single channel waveforms
    else
        S.waveform_singlechannels_label = 0; %1 to plot single channel waveforms
    end
    S.wave_plot_conditions_together = 0; %1 for plotting the average of all
    S.mag_lab = 1; %1 for magnetometers; 2 for gradiometers
    
    %averaged waveform plotting
    S.waveform_average_label = 1; %average of some channels
    S.left_mag = channels_plot; %13 %37 (visual) %43 (visual) %199 (visual) %203 (visual) %channels for averaging
    clustplot = chosen_clust{CL(cc),3}; %slightly elaborated way to get the channel original IDs of channels forming the significant cluster that you are considering
    S.left_mag = [];
    for ii = 1:size(clustplot,1)
        S.left_mag(ii) = find(cellfun(@isempty,strfind(chanlabels,clustplot{ii,1})) == 0);
    end
    % S.left_mag = [2:2:204];
    S.legc = 0; %set 1 for legend
    % S.left_mag = 99;
    S.signtp = {CL2{cc}};
    % S.sr = 150; %sampling rate (Hz)
    S.avewave_contrast = 0; %1 to plot the contrast between conditions (averaged waveform)
    S.save_label_waveaverage = 0;
    S.label_plot = 'c';
    %t-tests
    S.t_test_for_permutations = 0;
    S.cond_ttests_tobeplotted_topoplot = [1 2]; %this is for both topoplot and t-tests!! (here [1 2] means cond1 vs cond2!!!!!!!)
    S.magabs = 1;
    
    %topoplotting
    S.topoplot_label = 1;
    S.fieldtrip_mask = '/projects/MINDLAB2017_MEG-LearningBach/scripts/Leonardo_FunctionsPhD/External';
    S.topocontr = 0;
    S.topocondsing = pos_l; %condition for topoplot
    S.xlim = [CL2{cc}];
    S.zlimmag = [-200 200]; %magnetometers amplitude topoplot limits
    S.zlimgrad = [1 7]; %gradiometers amplitude topoplot limits
    S.colormap_spec = 0;
    % x = []; x.bottom = [0 0 1]; x.botmiddle = [0 0.5 1]; x.middle = [1 1 1]; x.topmiddle = [1 1 0.5]; x.top = [1 0.95 0]; %yellow - blue
    x = []; x.bottom = [0 0 0.5]; x.botmiddle = [0 0.5 1]; x.middle = [1 1 1]; x.topmiddle = [1 0 0]; x.top = [0.6 0 0]; %red - blue
    S.colormap_spec_x = x;
    S.topoplot_save_label = 0;
    
    [out] = MEG_sensors_plotting_ttest_LBPD_D2(S);
end

%%

%%

%% *** SOURCE RECONSTRUCTION ***

%%

%% LBPD_startup_D

pathl = '/projects/MINDLAB2017_MEG-LearningBach/scripts/Leonardo_FunctionsPhD'; %path to stored functions
addpath(pathl);
LBPD_startup_D(pathl);

%% CREATING 8mm PARCELLATION FOR EASIER INSPECTION IN FSLEYES
%OBS!! This section is done only for better handling of some visualization purposes, but it does not affect any of the beamforming algorithm;
% it is just important not to mix up the MNI coordinates, thus I would recommend to use the following lines


%1) USE load_nii TO LOAD A PREVIOUS NIFTI IMAGE
imag_8mm = load_nii('/scratch7/MINDLAB2017_MEG-LearningBach/DTI_Portis/Templates/MNI152_T1_8mm_brain.nii.gz');
Minfo = size(imag_8mm.img); %get info about the size of the original image
M8 = zeros(Minfo(1), Minfo(2), Minfo(3)); %Initialize an empty matrix with the same dimensions as the original .nii image
cc = 0; %set a counter
M1 = imag_8mm.img;
for ii = 1:Minfo(1) %loop across each voxel of every dimension
    for jj = 1:Minfo(2)
        for zz = 1:Minfo(3)
            if M1(ii,jj,zz) ~= 0 %if we have an actual brain voxel
                cc = cc+1;
                M8(ii,jj,zz) = cc;
            end
        end
    end
end
%2) PUT YOUR MATRIX IN THE FIELD ".img"
imag_8mm.img = M8; %assign values to new matrix 
%3) SAVE NIFTI IMAGE USING save_nii
save_nii(imag_8mm,'/scratch7/MINDLAB2017_MEG-LearningBach/DTI_Portis/Templates/MNI152_8mm_brain_diy.nii.gz');
%4) USE FSLEYES TO LOOK AT THE FIGURE
%Create parcellation on the 8mm template
for ii = 1:3559 %for each 8mm voxel
    cmd = ['fslmaths /scratch7/MINDLAB2017_MEG-LearningBach/DTI_Portis/Templates/MNI152_8mm_brain_diy.nii.nii.gz -thr ' num2str(ii) ' -uthr ' num2str(ii) ' -bin /scratch7/MINDLAB2017_MEG-LearningBach/DTI_Portis/Templates/AAL_80mm_3559ROIs/' num2str(ii) '.nii.gz'];
    system(cmd)
    disp(ii)
end
%5) GET MNI COORDINATES OF THE NEW FIGURE AND SAVE THEM ON DISK
MNI8 = zeros(3559,3);
for mm = 1:3559 %over brain voxel
    path_8mm = ['/scratch7/MINDLAB2017_MEG-LearningBach/DTI_Portis/Templates/parcel_80mm_3559ROIs/' num2str(mm) '.nii.gz']; %path for each of the 3559 parcels
    [mni_coord,pkfo] = osl_mnimask2mnicoords(path_8mm);  %getting MNI coordinates
    MNI8(mm,:) = mni_coord; %storing MNI coordinates
end
%saving on disk
save('/scratch7/MINDLAB2017_MEG-LearningBach/DTI_Portis/Templates/MNI152_8mm_coord_dyi.mat', 'MNI8');


%% CONVERSION T1 - DICOM TO NIFTI

addpath('/projects/MINDLAB2017_MEG-LearningBach/scripts/osl/dicm2nii'); %adds path to the dcm2nii folder in osl
MRIsubj = dir('/raw/sorted/MINDLAB2018_MEG-LearningBach-MemoryInformation/0*');
MRIoutput = '/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/Source_LBPD/MRI_nifti';

for ii = 1:length(MRIsubj) %over subjects
    asd = [MRIoutput '/' MRIsubj(ii).name];
    if ~exist(asd,'dir') %checking whether the directory exists
        mkdir(asd); %if not, creating it
    end
    if isempty(dir([asd '/*.nii'])) %if there are no nifti images.. I need to convert them
        flagg = 0;
        MRIMEGdate = dir([MRIsubj(ii).folder '/' MRIsubj(ii).name '/20*']);
        niiFolder = asd;
        for jj = 1:length(MRIMEGdate) %over dates of recording
            %                     if ~isempty(dir([MRIMEGdate(jj).folder '/' MRIMEGdate(jj).name '/MR*'])) %if we get an MRI recording
            MRI2 = dir([MRIMEGdate(jj).folder '/' MRIMEGdate(jj).name '/MR/*INV2']); %looking for T1
            if length(MRI2) == 1 %if we have one T1
                flagg = 1; %determining that I could convert MRI T1
                dcmSource = [MRI2(1).folder '/' MRI2(1).name '/files/'];
                dicm2nii(dcmSource, niiFolder, '.nii');
            end
            if length(MRI2) ~= 1 && jj == length(MRIMEGdate)
                warning(['subject ' MRIsubj(ii).name ' has no MRI T1 or has more than 1 MRI T1']);
                warning('copying brain template..')
                copyfile('/projects/MINDLAB2017_MEG-LearningBach/scripts/Leonardo_FunctionsPhD/External/MNI152_T1_2mm.nii',[niiFolder '/MNI152_T1_2mm.nii'])
            end
        end
        if ~isempty(dir([niiFolder '/*.txt'])) %if something goes wrong with the conversion of the MRI file, I copy-paste a template
            warning(['something wrong with MRI of subject ' MRIsubj(ii).name]);
            warning('copying brain template..')
            copyfile('/projects/MINDLAB2017_MEG-LearningBach/scripts/Leonardo_FunctionsPhD/External/MNI152_T1_2mm.nii',[niiFolder '/MNI152_T1_2mm.nii'])
        end
    end
    disp(ii)
end

%% SETTING FOR CLUSTER (PARALLEL COMPUTING)

% clusterconfig('scheduler', 'none'); %If you do not want to submit to the cluster, but simply want to test the script on the hyades computer, you can instead of 'cluster', write 'none'
clusterconfig('scheduler', 'cluster'); %If you do not want to submit to the cluster, but simply want to test the script on the hyades computer, you can instead of 'cluster', write 'none'
clusterconfig('long_running', 1); % This is the cue we want to use for the clsuter. There are 3 different cues. Cue 0 is the short one, which should be enough for us
clusterconfig('slot', 1); %slot is memory, and 1 memory slot is about 8 GB. Hence, set to 2 = 16 GB
addpath('/projects/MINDLAB2017_MEG-LearningBach/scripts/Cluster_ParallelComputing')

%% RHINO coregistration

%block to be run RHINO coregistrartion on
list = dir ('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/e*mat'); %dir to epoched files (encoding)
extr2 = 13:16;

%running rhino
%OBS! check that all MEG data are in the same order and number as MRI nifti files!
a = ['/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/Source_LBPD/MRI_nifti']; %set path to MRI subjects' folders
for ii = 1:length(list) %OBS! change this depending on atonal vs. major
    S = [];
    S.ii = ii;
    S.D = [list(ii).folder '/' list(ii).name]; %path to major files
    D = spm_eeg_load(S.D);
    if ~isfield(D,'inv') %checking if the coregistration was already run
        dummyname = D.fname;
        if 7 == exist([a '/' dummyname(extr2)],'dir') %if you have the MRI folder
            dummymri = dir([a '/' dummyname(extr2) '/*.nii']); %path to nifti files (ending with .nii)
            if ~isempty(dummymri)
                S.mri = [dummymri(1).folder '/' dummymri(1).name];
                %standard parameters
                S.useheadshape = 1;
                S.use_rhino = 1; %set 1 for rhino, 0 for no rhino
                %         S.forward_meg = 'MEG Local Spheres';
                S.forward_meg = 'Single Shell'; %CHECK WHY IT SEEMS TO WORK ONLY WITH SINGLE SHELL!!
                S.fid.label.nasion = 'Nasion';
                S.fid.label.lpa = 'LPA';
                S.fid.label.rpa = 'RPA';
                jobid = job2cluster(@coregfunc,S); %running with parallel computing
            else
                warning(['subject ' dummyname(extr2) ' does not have the MRI'])
            end
        end
    else
        if isempty(D.inv{1}) %checking whether the coregistration was run but now it is empty..
            warning(['subject ' D.fname ' has an empty rhino..']);
        end
    end
    disp(ii)
end

%% checking (or copying) RHINO

copy_label = 2; % 1 = pasting inv RHINO from epoched data (where it was computed) to continuous data (not supported for block 6); 0 = simply showing RHINO coregistration; 2 = copy-pasting inv RHINO from long epoched data to short epoched data (since the files are exactly the same..)

list = dir ('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/espm*mat'); %dir to epoched files
list2 = dir ('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/esspm*mat'); %dir to epoched files
for ii = 13%:length(list)
    D = spm_eeg_load([list(ii).folder '/' list(ii).name]);
    if isfield(D,'inv')
        if copy_label == 0 %simply displaying RHINO coregistration
            if isfield(D,'inv') %checking if the coregistration was already run
                rhino_display(D)
            end
        elseif copy_label == 1 %pasting inv RHINO from epoched data (where it was computed) to continuous data
            inv_rhino = D.inv;
            D2 = spm_eeg_load([list(ii).folder '/' list(ii).name(2:end)]);
            D2.inv = inv_rhino;
            D2.save();
        elseif copy_label == 2 %list and list2 have the same amount of elements
            inv_rhino = D.inv;
            D2 = spm_eeg_load([list2(ii).folder '/' list2(ii).name]);
            D2.inv = inv_rhino;
            D2.save();
        end
    end
    disp(['Subject ' num2str(ii)])
end
%block 4 subj 1

%%

%% BEAMFORMING

%% SETTING FOR CLUSTER (PARALLEL COMPUTING)

% clusterconfig('scheduler', 'none'); %If you do not want to submit to the cluster, but simply want to test the script on the hyades computer, you can instead of 'cluster', write 'none'
clusterconfig('scheduler', 'cluster'); %If you do not want to submit to the cluster, but simply want to test the script on the hyades computer, you can instead of 'cluster', write 'none'
clusterconfig('long_running', 1); % This is the cue we want to use for the clsuter. There are 3 different cues. Cue 0 is the short one, which should be enough for us
clusterconfig('slot', 1); %slot is memory, and 1 memory slot is about 8 GB. Hence, set to 2 = 16 GB
addpath('/projects/MINDLAB2017_MEG-LearningBach/scripts/Cluster_ParallelComputing')

%% FUNCTION FOR SOURCE RECONSTRUCTION

%user settings
epoch_l = 2; %1 = long epoch including the first sound repeated three times, the distractor and then the target sound; 2 = short epoch, including only the target sound
clust_l = 1; %1 = using cluster of computers (CFIN-MIB, Aarhus University); 0 = running locally
if epoch_l == 1
    timek = 1:3000; %time-points
    workingdir2 = '/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/Source_LBPD'; %high-order working directory (a subfolder for each analysis with information about frequency, time and absolute value will be created)
    extr2 = 13:16;
    list = dir ('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/espm*mat'); %dir to epoched files (encoding)
    load('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/time_long.mat');
else
    timek = 1:876; %time-points
    workingdir2 = '/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/Source_LBPD_shortepoch'; %high-order working directory (a subfolder for each analysis with information about frequency, time and absolute value will be created)
    extr2 = 14:17;
    list = dir ('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/after_maxfilter_mc/esspm*mat'); %dir to epoched files (encoding)
    load('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/time_short.mat');
end
freqq = []; %frequency range (empty [] for broad band)
% freqq = [0.1 1]; %frequency range (empty [] for broad band)
% freqq = [2 8]; %frequency range (empty [] for broad band)
sensl = 1; %1 = magnetometers only; 2 = gradiometers only; 3 = both magnetometers and gradiometers (SUGGESTED 1!)
invers = 1; %1-4 = different ways (e.g. mean, t-values, etc.) to aggregate trials and then source reconstruct only one trial; 5 for single trial independent source reconstruction

% if isempty(freqq)
    absl = 0; % 1 = absolute value of sources; 0 = not
% else
%     absl = 0;
% end

%actual computation
%list of subjects with coregistration (RHINO - OSL/FSL) - epoched
condss = {'Old','New'};

if isempty(freqq)
    workingdir = [workingdir2 '/Beam_abs_' num2str(absl) '_sens_' num2str(sensl) '_freq_broadband_invers_' num2str(invers)];
else
    workingdir = [workingdir2 '/Beam_abs_' num2str(absl) '_sens_' num2str(sensl) '_freq_' num2str(freqq(1)) '_' num2str(freqq(2)) '_invers_' num2str(invers)];
end
addpath('/projects/MINDLAB2017_MEG-LearningBach/scripts/Cluster_ParallelComputing');
if ~exist(workingdir,'dir') %creating working folder if it does not exist
    mkdir(workingdir)
end
for ii = 1:length(list) %over subjects
    if ii ~= 12
        S = [];
        if ~isempty(freqq) %if you want to apply the bandpass filter, you need to provide continuous data
            %             disp(['copying continuous data for subj ' num2str(ii)])
            %thus pasting it here
            %             copyfile([list_c(ii).folder '/' list_c(ii).name],[workingdir '/' list_c(ii).name]); %.mat file
            %             copyfile([list_c(ii).folder '/' list_c(ii).name(1:end-3) 'dat'],[workingdir '/' list_c(ii).name(1:end-3) 'dat']); %.dat file
            %and assigning the path to the structure S
            S.norm_megsensors.MEGdata_c = [list(ii).folder '/' list(ii).name(2:end)];
        end
        %copy-pasting epoched files
        %         disp(['copying epoched data for subj ' num2str(ii)])
        %         copyfile([list(ii).folder '/' list(ii).name],[workingdir '/' list(ii).name]); %.mat file
        %         copyfile([list(ii).folder '/' list(ii).name(1:end-3) 'dat'],[workingdir '/' list(ii).name(1:end-3) 'dat']); %.dat file
        
        S.Aarhus_cluster = clust_l; %1 for parallel computing; 0 for local computation
        
        S.norm_megsensors.zscorel_cov = 1; % 1 for zscore normalization; 0 otherwise
        S.norm_megsensors.workdir = workingdir;
        S.norm_megsensors.MEGdata_e = [list(ii).folder '/' list(ii).name];
        S.norm_megsensors.freq = freqq; %frequency range
        S.norm_megsensors.forward = 'Single Shell'; %forward solution (for now better to stick to 'Single Shell')
        
        S.beamfilters.sensl = sensl; %1 = magnetometers; 2 = gradiometers; 3 = both MEG sensors (mag and grad) (SUGGESTED 3!)
        S.beamfilters.maskfname = '/projects/MINDLAB2017_MEG-LearningBach/scripts/Leonardo_FunctionsPhD/External/MNI152_T1_8mm_brain.nii.gz'; % path to brain mask: (e.g. 8mm MNI152-T1: '/projects/MINDLAB2017_MEG-LearningBach/scripts/Leonardo_FunctionsPhD/External/MNI152_T1_8mm_brain.nii.gz')
        
        %%% CHECK THIS ONE ESPECIALLY!!!!!!! %%%
        S.inversion.znorml = 0; % 1 for inverting MEG data using the zscored normalized one; (SUGGESTED 0 IN BOTH CASES!)
        %                                 0 to normalize the original data with respect to maximum and minimum of the experimental conditions if you have both magnetometers and gradiometers.
        %                                 0 to use original data in the inversion if you have only mag or grad (while e.g. you may have used zscored-data for covariance matrix)
        %
        S.inversion.timef = timek; %data-points to be extracted (e.g. 1:300); leave it empty [] for working on the full length of the epoch
        S.inversion.conditions = condss; %cell with characters for the labels of the experimental conditions (e.g. {'Old_Correct','New_Correct'})
        S.inversion.bc = [1 26]; %extreme time-samples for baseline correction (leave empty [] if you do not want to apply it)
        S.inversion.abs = absl; %1 for absolute values of sources time-series (recommendnded 1!)
        S.inversion.effects = invers;
        
        S.smoothing.spatsmootl = 0; %1 for spatial smoothing; 0 otherwise
        S.smoothing.spat_fwhm = 100; %spatial smoothing fwhm (suggested = 100)
        S.smoothing.tempsmootl = 0; %1 for temporal smoothing; 0 otherwise
        S.smoothing.temp_param = 0.01; %temporal smoothing parameter (suggested = 0.01)
        S.smoothing.tempplot = [1 2030 3269]; %vector with sources indices to be plotted (original vs temporally smoothed timeseries; e.g. [1 2030 3269]). Leave empty [] for not having any plot.
        
        S.nifti = 1; %1 for plotting nifti images of the reconstructed sources of the experimental conditions
        S.out_name = ['SUBJ_' list(ii).name(extr2)]; %name (character) for output nifti images (conditions name is automatically detected and added)
        
        if clust_l ~= 1 %useful  mainly for begugging purposes
            MEG_SR_Beam_LBPD(S);
        else
            jobid = job2cluster(@MEG_SR_Beam_LBPD,S); %running with parallel computing
        end
    end
end


%% SETTING FOR CLUSTER (PARALLEL COMPUTING)

% clusterconfig('scheduler', 'none'); %If you do not want to submit to the cluster, but simply want to test the script on the hyades computer, you can instead of 'cluster', write 'none'
clusterconfig('scheduler', 'cluster'); %If you do not want to submit to the cluster, but simply want to test the script on the hyades computer, you can instead of 'cluster', write 'none'
clusterconfig('long_running', 1); % This is the cue we want to use for the clsuter. There are 3 different cues. Cue 0 is the short one, which should be enough for us
clusterconfig('slot', 2); %slot is memory, and 1 memory slot is about 8 GB. Hence, set to 2 = 16 GB
addpath('/projects/MINDLAB2017_MEG-LearningBach/scripts/Cluster_ParallelComputing')


%% STATISTICS OVER PARTICIPANTS (USING PARALLEL COMPUTING, PARTICULARLY USEFUL IF YOU HAVE SEVERAL CONTRASTS)

epoch_l = 2; %1 = long epoch including the first sound repeated three times, the distractor and then the target sound; 2 = short epoch, including only the target sound
clust = 1; % 1 = using Aarhus cluster (parallel computing); 0 = run locally
analys_n = 1; %analysis number (in the list indexed below)

%building structure
if epoch_l == 1
    asd = dir(['/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/Source_LBPD/Beam*']);
else
    asd = dir(['/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/Source_LBPD_shortepoch/Beam*']);
end
S = [];
S.workingdir = [asd(analys_n).folder '/' asd(analys_n).name]; %path where the data from MEG_SR_Beam_LBPD.m is stored
S.list = [];
S.plot_nifti_name = []; %character with name for nifti files (it may be useful if you run separate analysis); Leave empty [] to not  specify any name
S.sensl = 1; % 1 = magnetometers only; 2 = gradiometers only; 3 = both magnetometers and gradiometers.
S.plot_nifti = 1; %1 to plot nifti images; 0 otherwise
% S.contrast = [1 0 0 0 0 0 -1; 0 1 0 0 0 0 -1; 0 0 1 0 0 0 -1; 0 0 0 1 0 0 -1; 0 0 0 0 1 0 -1; 0 0 0 0 0 1 -1; 1 1 1 1 1 1 -1]; %one row per contrast (e.g. having 3 conditions, [1 -1 0; 1 -1 -1; 0 1 -1]; two or more -1 or 1 are interpreted as the mean over them first and then the contrast. Leave empty [] for no contrasts. 
S.contrast = [1 -1];
S.effects = 1; %mean over subjects for now
if clust == 1
    S.Aarhus_clust = 1; %1 to use paralle computing (Aarhus University, contact me, Leonardo Bonetti, for more information; leonardo.bonetti@clin.au.dk)
    %actual function
    jobid = job2cluster(@MEG_SR_Stats1_Fast_LBPD,S); %running with parallel computing
else
    S.Aarhus_clust = 0; %1 to use paralle computing (Aarhus University, contact me, Leonardo Bonetti, for more information; leonardo.bonetti@clin.au.dk)
    MEG_SR_Stats1_Fast_LBPD(S)
end

%% EXTRACTING (AND TESTING) SOURCE RECONSTRUCTED DATA INTHE SIGNIFICANT TIME-WINDOWS AT MEG SENSOR LEVEL

%pos times and sizes: 0.53 - 0.6 (k = 47); 0.08 - 0.12 (k = 46); 0.29 - 0.34 (k = 41)
%neg times and sizes: 0.70 - 0.78 (k = 91); 0.43 - 0.53 (k = 79); 0.58 - 0.64 (k = 68)

%loading data and computing t-tests for each brain voxel within the time-windows reported above
posl = 0; %1 = time-windows for positive contrasts (when Old > New); 0 for New > Old


%list of subjects
list = dir('/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/Source_LBPD_shortepoch/Beam_abs_1_sens_1_freq_broadband_invers_1/SUBJ*.mat');
if posl == 1
    timewind = [159 176; 46 56; 99 111]; %time-windows
else
    timewind = [201 221; 134 159; 171 186]; %time-windows
end
%loading and preparing data
data = zeros(3559,length(timewind),2,length(list)); %brain voxels, time-windows, conditions, subjects
for ii = 1:length(list) %over subjects
    load([list(ii).folder '/' list(ii).name]) %loading subject ii
    for ww = 1:size(timewind,1) %over the time-windows that we defined
        data(:,ww,1,ii) = mean(OUT.sources_ERFs(:,timewind(ww,1):timewind(ww,2),1),2); %extracting data and averaging it over the time-window (Old)
        data(:,ww,2,ii) = mean(OUT.sources_ERFs(:,timewind(ww,1):timewind(ww,2),2),2); %New
    end
    disp(ii)
end
%t-tests
P = zeros(3559,length(timewind)); %brain voxels, time-windows
T = zeros(3559,length(timewind));
RAW = zeros(3559,length(timewind));
for ii = 1:size(P,1) %over brain voxels
    for jj = 1:size(P,2) %over time-windows
        [~,p,~,stats] = ttest(squeeze(data(ii,jj,1,:)),squeeze(data(ii,jj,2,:))); %contrasting Old vs New
        if posl == 1 %if positive contrast we want to plot only the Old condition
            RAW(ii,jj) = mean(data(ii,jj,1,:),4);
        else %otherwise the New condition
            RAW(ii,jj) = mean(data(ii,jj,2,:),4);
        end
        P(ii,jj) = p;
        T(ii,jj) = stats.tstat;
    end
    disp(ii)
end
RAW = RAW./122.1251; %standardising values between 0 and 1 to allow easier inspection later (Old and New together, 68.3514 was the value that I previously isolated)
%printing nifti images
if posl == 1
    fnameniipath = ['/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/Source_LBPD_shortepoch/Beam_abs_1_sens_1_freq_broadband_invers_1/Contrasts/OldVsNew']; %/Timewindow_1_10.nii.gz']; %path and name of the image to be saved
    NAM = 'OldvsNew';
else
    fnameniipath = ['/scratch7/MINDLAB2018_MEG-LearningBach-MemoryInformation/Abir/Source_LBPD_shortepoch/Beam_abs_1_sens_1_freq_broadband_invers_1/Contrasts/NewVsOld']; %path and name of the image to be saved
    NAM = 'NewvsOld';
end
%building nifti images (source reconstructed data averaged within the time-windows
for pp = 1:length(timewind)
    %RAW values after source reconstruction
    maskk = load_nii('/projects/MINDLAB2017_MEG-LearningBach/scripts/Leonardo_FunctionsPhD/External/MNI152_8mm_brain_diy.nii.gz'); %getting the mask for creating the figure
    SS = size(maskk.img);
    dumimg = zeros(SS(1),SS(2),SS(3));
    for ii = 1:size(RAW,1) %over brain sources
        dum = find(maskk.img == ii); %finding index of sources ii in mask image (MNI152_8mm_brain_diy.nii.gz)
        [i1,i2,i3] = ind2sub([SS(1),SS(2),SS(3)],dum); %getting subscript in 3D from index
        dumimg(i1,i2,i3) = RAW(ii,pp); %storing values for all time-points in the image matrix
    end
    nii = make_nii(dumimg,[8 8 8]);
    nii.img = dumimg; %storing matrix within image structure
    nii.hdr.hist = maskk.hdr.hist; %copying some information from maskk
    disp(['saving nifti image'])
    fnamenii = [fnameniipath '/RAW_' NAM '_tw' num2str(pp) '.nii.gz'];
    save_nii(nii,fnamenii); %printing image
end
%building nifti images (T and P values)
for pp = 1:length(timewind)
    %T-values
    maskk = load_nii('/projects/MINDLAB2017_MEG-LearningBach/scripts/Leonardo_FunctionsPhD/External/MNI152_8mm_brain_diy.nii.gz'); %getting the mask for creating the figure
    SS = size(maskk.img);
    dumimg = zeros(SS(1),SS(2),SS(3));
    for ii = 1:size(T,1) %over brain sources
        dum = find(maskk.img == ii); %finding index of sources ii in mask image (MNI152_8mm_brain_diy.nii.gz)
        [i1,i2,i3] = ind2sub([SS(1),SS(2),SS(3)],dum); %getting subscript in 3D from index
        dumimg(i1,i2,i3) = T(ii,pp); %storing values for all time-points in the image matrix
    end
    nii = make_nii(dumimg,[8 8 8]);
    nii.img = dumimg; %storing matrix within image structure
    nii.hdr.hist = maskk.hdr.hist; %copying some information from maskk
    disp(['saving nifti image'])
    fnamenii = [fnameniipath '/T_' NAM '_tw' num2str(pp) '.nii.gz'];
    save_nii(nii,fnamenii); %printing image
    %P-values
    maskk = load_nii('/projects/MINDLAB2017_MEG-LearningBach/scripts/Leonardo_FunctionsPhD/External/MNI152_8mm_brain_diy.nii.gz'); %getting the mask for creating the figure
    SS = size(maskk.img);
    dumimg = zeros(SS(1),SS(2),SS(3));
    for ii = 1:size(P,1) %over brain sources
        dum = find(maskk.img == ii); %finding index of sources ii in mask image (MNI152_8mm_brain_diy.nii.gz)
        [i1,i2,i3] = ind2sub([SS(1),SS(2),SS(3)],dum); %getting subscript in 3D from index
        dumimg(i1,i2,i3) = 1 - P(ii,pp); %storing values for all time-points in the image matrix
    end
    nii = make_nii(dumimg,[8 8 8]);
    nii.img = dumimg; %storing matrix within image structure
    nii.hdr.hist = maskk.hdr.hist; %copying some information from maskk
    disp(['saving nifti image'])
    fnamenii = [fnameniipath '/P_' NAM '_tw' num2str(pp) '.nii.gz'];
    save_nii(nii,fnamenii); %printing image
end


%%

