% -------------------------------------------------------------------------
% Script Name:     individual_waveforms.m
% Author:          Elisa Serra
% Date:            01-03-2025
% 
% Description:
% This script plots MEG sensor data to display both average and individual 
% waveforms for same and different target stimuli in a same/different task.
%
% Based on:
% Portions of this code are adapted from Lonardo Bonetti, pipeline_preproc_STM_sounds.m,
% available at
% https://github.com/leonardob92/MEG_STM_OneNote/blob/main/pipeline_preproc_STM_sounds.m

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% leonardo.bonetti@clin.au.dk
% Leonardo Bonetti, Aarhus, DK, 25/06/2019
% Leonardo Bonetti, MIT, Boston, USA, 12/08/2019
% Leonardo Bonetti, Aarhus, DK, 08/10/2019

% elisa.serra@psych.ox.ac.uk
% Elisa Serra, Oxford, UK, 01/03/2025


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Load data and cluster selection
pos_l = 2;  % Positive contrast (Old vs New)
load('/Users/elisa/Desktop/Elisa_24_02_2025/Mag_clust_oldvsnew.mat');
load([outdir '/Block_simpleoldnew_short.mat'],'time_sel','data_mat','chanlabels');

% Choose appropriate cluster based on the contrast
if pos_l == 1
    chosen_clust = MAG_clust_pos; % Positive contrast
    CL = [9,7,11]; % Cluster indices for Old vs New
    CL2{1} = [0.53 0.60]; CL2{2} = [0.08 0.12]; CL2{3} = [0.29 0.34]; % Significant time windows
else
    chosen_clust = MAG_clust_neg; % Negative contrast
    CL = [5,3,7];
    CL2{1} = [0.70 0.78]; CL2{2} = [0.43 0.53]; CL2{3} = [0.58 0.64];
end

% Select channels corresponding to the chosen cluster
clustplot = chosen_clust{CL(3), 3}; % Get cluster data
selected_chans = [];
for ii = 1:size(clustplot,1)
    selected_chans(ii) = find(cellfun(@isempty, strfind(chanlabels, clustplot{ii, 1})) == 0);
end

% Average over the selected channels for both "Same" and "Different" conditions
same_data = squeeze(mean(data_mat(selected_chans, :, :, 1), 1));  % "Same" condition
diff_data = squeeze(mean(data_mat(selected_chans, :, :, 2), 1));  % "Different" condition

% Plotting the average time series and individual subject plots
figure;
hold on;

% Plot individual subject traces (finer lines for transparency)
for subj_idx = 1:size(data_mat, 3)
    plot(time_sel, same_data(:, subj_idx), 'b', 'LineWidth', 0.3, 'Color', [0 0 1 0.3]);  % Blue for "Same"
    plot(time_sel, diff_data(:, subj_idx), 'Color', [1 0.5 0 0.3], 'LineWidth', 0.3);  % Orange for "Different"
end

% Plot the average waveforms for both conditions (thicker lines)
plot(time_sel, mean(same_data, 2), 'b', 'LineWidth', 2);  % Blue for "Same"
plot(time_sel, mean(diff_data, 2), 'Color', [1, 0.5, 0], 'LineWidth', 2);  % Orange for "Different"

% Add grey shaded areas for significant time windows
if ~isempty(S.signtp{1})
    patch_color = [.85 .85 .85];  % Grey for significant time window
    ylims = get(gca, 'YLim');
    for ii = 1:length(S.signtp)
        sgf2 = S.signtp{ii};
        patch([sgf2(1) sgf2(end) sgf2(end) sgf2(1)], [ylims(1) ylims(1) ylims(2) ylims(2)], patch_color, 'EdgeColor', 'none', 'FaceAlpha', .4);
    end
end

% Customize plot
xlabel('Time (s)');
ylabel('Amplitude (fT)');
xlim([-0.1 1.5]);  % Set x-axis limits to [-0.1, 1.5] seconds
title(['Cluster ' num2str(CL(1)) ': Time Series Plot (Same vs Different)']);
grid on;
box on;

% Save the figure as PDF
exportgraphics(gcf, [outdir '/Cluster_' num2str(CL(1)) '_time_series_plot.pdf']);

% Display the plot
hold off;


