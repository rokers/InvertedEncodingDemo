% forwardModelDemo: Illustrate the principle of inverted encoding models
% 
% Implementation for 3D motion perception
% by Bas Rokers (rokers@nyu.edu) 
% Baseed on demo of forward model for estimating
% tuning functions (TFs)
% js: 9.9.2014, (jserences@ucsd.edu)

% Relevant papers:
% Brouwer & Heeger, 2009 - http://www.jneurosci.org/content/jneuro/29/44/13992.full.pdf
% Kok, Brouwer et al, 2013 - http://www.jneurosci.org/content/jneuro/33/41/16275.full.pdf
% Sprague, Ester, Serences, 2014 - https://ac.els-cdn.com/S096098221400935X/1-s2.0-S096098221400935X-main.pdf?_tid=53d0885f-0d19-48e9-af55-f652ebb3e622&acdnat=1522855295_28aadf34bf55b19e10622f84c05e00ee

% Requirements
% Matlab wavelet toolbox (wshift)
% Matlab deep learning toolbox (plotconfusion)
set(0, 'DefaultLineLineWidth', 2); % Set figure linewidth default

restoredefaultpath
clear all;
close all;

%% Section 0: Parameters

% Encoding model
nChans      = 8; % number of channels in your model (does not have to match # stim features).
exponent    = 5; % Excercise: evaluate the effect of exponent

% Data
nDirections = 8; % number of stimulus directions in your study
nRepeats    = 20; % number repeats of each motion direction for the simulation
nTrials     = nRepeats * nDirections; % number of trials in your experiment.

%% Section 1: Build encoding model

% design the basis function for estimating the channel weights in each voxel
xs = linspace(0, 360-360/nChans, nChans); 
for ii = 1:nChans
    bf(:,ii) = cosd(xs-(ii-1)*45).^exponent;
end
bf = max(0,bf); % rectify
bf = bf./max(bf); % norm to unit height

% Plot model
figure; hold on
ph = plot([xs 360],[bf; bf(1,:)]'); % repeat 0 deg data at 360
xlabel({' ','Motion Direction (deg)'})
ylabel({' ','Channel Response',' '});
title('Encoding model')
axis([0 360 0 1]);
xticks(0:45:360);
yticks(0:.25:1);

%% Section 2: Load data 
% Data is nTrials x nVoxels

% This demo contains V1, MT and IPS data for one participant (br)
% 3D motion stimuli are presented in 8 labeled directions, where
% 1: rightward, 3: towards, 5:leftward, and 7: away. 
% Intermediate values reflect intermediate directions moving directly
% towards or away from one of the eyes

load('workspace.mat')
% Contains rois (roi names), new_p (parameters), 
% and masked_ds (trials x voxels dataset organized by roi)
whichRoi = 1; % V1 - 1, hMT - 2, IPS - 3
data = masked_ds{whichRoi}.samples;
g = round(new_p.stimval./22.5); % ground truth, convert back to labels 1-8
block = new_p.runNs; % block/scan indices

% Inspect data and verify that it is zero mean, 
% detrended and normalized (z-scored)
figure
imagesc(data)
title('Measured voxel response')
xlabel('Voxel #')
ylabel('Trial #')

% Old (UW data)
% load('myData_br_V1.mat')
% load('myData_br_MT.mat') % contains trials x nVoxels
% load('myData_br_IPS.mat')

% data is trials x voxels
% data = [traindat; testdat]; % reconstitute. Data was originally 50/50 split
% g = [Truth; Truth]; % presented direction on each trial 
% block = sort(repmat((1:nRepeats)', nDirections, 1));

%% STEP 3: Hold one block out and solve for channel weights: 'Foward model'
runs = unique(block)'; % find the number of unique runs
chan = nan(nTrials, nChans); % initialize hold-one out channel responses 

for rr=runs % Hold out one run at a time
    fprintf('Computing iteration %d out of %d\n', rr, size(runs,2));
    
    trnind = (block ~= rr);     % set training data
    trn = data(trnind,:);       % data from training scans (all but one scan)
    tstind = (block == rr);     % set testing data
    tst = data(tstind,:);       % data from test scan (held out scan)
    
    trng = g(trnind);           % trial labels for training data.
    tstg = g(tstind);           % trial labels for test data.

    % create the design matrix for computing channel weights in each voxel
    X = zeros(size(trn,1), nChans); % initialize predicted channel responses
    for ii=1:size(trn,1)
        % populate predicted channel responses 
        X(ii,:) = bf(:,trng(ii)); % rows: observations (trials), columns: predicted response of each orientation channel 
    end
    
    % use a GLM to compute weight of each channel in each
    % voxel, based on data from the training set.
    w = X\trn; % channel weights matrix - or inv(X'*X)*X'*trn; 

    % then invert and apply to test data ...
    % basically, you solved for the weights using the
    % training data, now you have some observed data from the test set, and
    % you want to infer the channel response profile (tuning function) that
    % best maps the known selectivity of each voxel (w) to the test data
    x = (w'\tst')';  % reconstructed channel responses - or (inv(w*w')*w*tst')'
    
    % stack up the channel responses from each iteration of holding
    % one-scan out... chan contains blocks by directions (20x8) by channels (8)
    chan(rr*nDirections-nDirections+1:rr*nDirections,:) = x;
    
end

%% Visualize Results %%

%% Plot channel weights (w) for a sample voxel
figure; hold on
whichVoxel = 100; % Pick a sample voxel
bar(w(:,whichVoxel))
xlabel('Channel')
ylabel('Weight')
title(['Channel weights (voxel ' num2str(whichVoxel) ')'])
xlim([.5 8.5])

%% Plot reconstructed channel responses (x) for one iteration
figure; hold on
plot([xs 360],[x x(:,1)])
title('Reconstructed channel response for 1 iteration')
xlabel('Direction (deg)')
ylabel('Channel response')
xticks([0:45:360])
xlim([0 360])
lh = legend(cellfun(@num2str,num2cell(xs), 'UniformOutput',false));
set(lh, 'Location', 'northeastoutside')
title(lh,'Presented direction')

%% Plot average channel responses (chan) across holdouts

% Compute average reconstructed channel response
for ii = 1:nDirections
    mean_chan(ii,:) = mean(chan(ii:nDirections:nTrials,:));
end

figure; hold on
plot([xs 360],[mean_chan mean_chan(:,1)])
title('Mean channel response (averaged over hold-outs)')
xlabel('Direction (deg)')
ylabel('Channel response')
xticks([0:45:360])
xlim([0 360])
lh = legend(cellfun(@num2str,num2cell(xs), 'UniformOutput',false));
set(lh, 'Location', 'northeastoutside')
title(lh,'Presented direction')


%% Plot confusion matrix (presented vs reconstructed (max x) over iterations

% compute predicted motion direction
for ii = 1:nTrials
    [~, pred(ii)] = max(chan(ii,:));
end
figure; hold on
plotconfusion(categorical(g),categorical(pred'),'Test')

%% Extra stuff follows below

%% Plot average tuning function for each cross-validated test stimulus

% Shift the rows (tf on each trial) so that the channel corresponding to the stimulus on
% each trial is in the middle column

for ii=1:size(chan,1)
   schan(ii,:) = wshift('1D', chan(ii,:), g(ii)-5); % center on 180 deg channel
end

figure, hold on
plot([-180:45:180], [mean(schan), mean(schan(:,1))],'o-')
plot([-180 180],[mean(mean(schan)) mean(mean(schan))],'k:'); % mean response
xlabel('Distance from Preferred Direction (deg)')
ylabel('Estimated Response')
title('Mean Tuning/Channel Response Function')
xlim([-180 180])
xticks([-180:45:360])


%% Plot tuning by motion direction
figure, hold on
for ii = 1:8
    ids = (g == ii);
    meanchan(ii,:)  = mean(chan(ids,:)) - mean(mean(chan(ids,:))); % mean normalized response
end
ph = plot([xs 360], [meanchan meanchan(:,1)],'o-'); % tuning each direction
plot([0 360],[mean(mean(chan)) mean(mean(chan))],'k:'); % mean response
lh = legend(cellfun(@num2str,num2cell(xs), 'UniformOutput',false));
set(lh, 'Location', 'northeastoutside')
title(lh,'Presented direction')

title('Reconstructed channel response')
xlabel('Direction Channel (deg)')
ylabel('Estimated Response')
xticks([0:45:360])
xlim([0 360])

%% Or as a matrix
% figure
% imagesc(meanchan)
% xlabel('Channels');
% ylabel('Stimuli');
% colorbar
% axis xy

%% How well did we do on the test set?
disp(['Overall accuracy: ' num2str(100.*mean(g == pred')) '%'])

