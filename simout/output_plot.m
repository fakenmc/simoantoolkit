function [d, h] = output_plot(...
    folder, files, outputs, type, layout, scale, iters, colors)
% OUTPUT_PLOT Plot time-series simulation output from one or more 
% replications using one of three approaches: superimposed, extremes or
% moving average.
%
%   [d, h] = OUTPUT_PLOT(folder, file, outputs, type, layout, scale, iters, colors)
%
% Parameters:
%      folder - Folder containing simulation output files.
%       files - Simulation output files (use wildcards for more than one
%               file).
%     outputs - Either an integer representing the number of outputs in 
%               each file or a cell array of strings with the output names.
%               In the former case, output names will be 'o1', 'o2', etc.
%        type - Type of plot:
%               'a' - Superimposed outputs (default).
%               'f' - Plot filled area encompassed by output extremes.
%               0...w - Moving average, window size w.
%      layout - Vector of integers specifying how many outputs to plot in
%               each figure. Number of elements in vector will correspond
%               to the number of figures, while the value of each element
%               in vector will correspond to the number of outputs plotted 
%               in each figure. By default all outputs are plotted in the 
%               same figure.
%       scale - Values in this vector are element-wise multiplied by the
%               corresponding outputs, and are used to scale outputs. If
%               only one element is given, all outputs are multiplied by
%               this element. Default is 1.
%       iters - Number of iterations to plot (default is 0, i.e., plot all
%               iterations).
%      colors - Cell array of strings specifying colors with which to plot 
%               each output within each figure. Default is 
%               {'b', 'r', 'g', 'c', 'm', 'y', 'k'}.
%
% Outputs:
%    d - Matrix containing what was plotted. First dimension corresponds to
%        the number of outputs, second dimension to the number of 
%        iterations. If plot is of type == 'a', third dimension corresponds
%        to number of files (i.e. replications). If plot is of type == 'f', 
%        third dimension is 2 (for minima and maxima at each iteration, 
%        respectively). If plot is of type moving average, d only has two
%        dimensions.
%    h - Handles of created figures.
%
%
% Copyright (c) 2015 Nuno Fachada
% Distributed under the MIT License (See accompanying file LICENSE or copy 
% at http://opensource.org/licenses/MIT)
%

% Read files containing outputs
listing = dir([folder '/' files]);
num_files = size(listing, 1);

% Were any files found?
if num_files == 0
    error('No files found.');
end;

% Load data from first file (used for defaults)
data = dlmread([folder '/' listing(1).name]);

% Default output names if respective arguments not given
if nargin < 3
    num_outputs = size(data, 2);
    outputs = parse_output_names(num_outputs);
else
    [outputs, num_outputs] = parse_output_names(outputs);
end;

% Default type
if nargin < 4
    type = 'a';
end;

% Default layout
if nargin < 5
    layout = num_outputs;
end;

% Default scale
if nargin < 6
    scale = ones(1, num_outputs);
elseif numel(scale) == 1
    scale = scale * ones(1, num_outputs);
end;

% Default number of iterations
if nargin < 7 || iters == 0
    iters = size(data, 1);
end;

% Default colors
if nargin < 8
    colors = {'b', 'r', 'g', 'c', 'm', 'y', 'k'}; 
end;

% Initialize data vector
all_data = zeros(num_outputs, iters, num_files);

% Load data from files
for i = 1:num_files
            
    data = dlmread([folder '/' listing(i).name]);
    for j = 1:num_outputs
        all_data(j, :, i) = data(1:iters, j);
    end;
    
end;

% Number of figures to create
num_figures = numel(layout);

% Handles of created figures
h = zeros(1, num_figures);

% Create figures
for cfig = 1:num_figures
    h(cfig) = figure();
    hold on;
    grid on;    
end;

% How to plot outputs?

if type == 'a' % All, superimposed
    
    % In this case, the output matrix will be all_data
    d = all_data;
    
    % Cycle through the requested figures
    i1 = 1; % First output to plot in next figure
    for cfig = 1:num_figures
        
        % How many outputs to plot in current figure
        l = layout(cfig);
        
        % Last output to plot in next figure
        i2 = i1 + l - 1;
        
        % Select current figure
        figure(h(cfig));
        
        % Cycle through replications
        for f = 1:num_files
            
            % Cycle through outputs to plot in current figure
            for i = i1:i2
                
                % Plot current output
                plot(all_data(i, 1:iters, f) * scale(i), ...
                    colors{i - i1 + 1});
    
            end;
            
        end;
        
        % Legend and axis labels
        xlim([0 iters]);
        legend(outputs(i1:i2));
        xlabel('Iterations');
        ylabel('Value');
        
        % First output to plot in next figure
        i1 = i2 + 1;
        
    end;
    
elseif type == 'f' % Filled
    
    % There are problems with the legends in octave
    if is_octave()
        warning('Legends may not appear correctly in Octave');
    end;
    
    % Initialize output matrix
    d = zeros(num_outputs, iters, 2);

    % Find extremes
    for i = 1:num_outputs
        d(i, :, 1) = min(all_data(i, :, :), [], 3);
        d(i, :, 2) = max(all_data(i, :, :), [], 3);
    end;
    
    % Cycle through the requested figures (number of figures corresponds to
    % the number of elements in variable "layout").
    i1 = 1; % First output to plot in next figure
    x = 1:iters; % Vector containing iterations to plot
    for cfig = 1:num_figures
        
        % How many outputs to plot in current figure
        l = layout(cfig);
        
        % Last output to plot in next figure
        i2 = i1 + l - 1;
        
        % Select current figure
        figure(h(cfig));
        
        % Cycle through outputs to plot in current figure
        for i = i1:i2
                
            % Plot extremes for current output
            fill_between(x, squeeze(d(i, :, 1)) * scale(i), ...
                squeeze(d(i, :, 2)) * scale(i), ...
                1, 'FaceColor', colors{i - i1 + 1});
    
        end;
        
        % Legend and axis labels
        xlim([0 iters]);
        legend(outputs(i1:i2));
        xlabel('Iterations');
        ylabel('Value');
        
        % First output to plot in next figure
        i1 = i2 + 1;
        
    end;
    
    
elseif isnumeric(type) && type >= 0 % Moving average
    
    % Window size
    w = type;
    
    % Initialize output matrix
    d = zeros(num_outputs, iters - w);
    
    % Find averages
    for i = 1:num_outputs
        
        d(i, :) = mavg(mean(all_data(i, :, :), 3), w);

    end;
    
    % Cycle through the requested figures (number of figures corresponds to
    % the number of elements in variable "layout").
    i1 = 1; % First output to plot in next figure
    for cfig = 1:num_figures
        
        % How many outputs to plot in current figure
        l = layout(cfig);
        
        % Last output to plot in next figure
        i2 = i1 + l - 1;
        
        % Select current figure
        figure(h(cfig));
        
        % Cycle through outputs to plot in current figure
        for i = i1:i2
            
            % Plot moving average for current output
            plot(d(i, :) * scale(i), ...
                colors{i - i1 + 1});
    
        end;
        
        % Legend and axis labels
        xlim([0 iters]);
        legend(outputs(i1:i2));
        xlabel('Iterations');
        ylabel('Value');
        
        % First output to plot in next figure
        i1 = i2 + 1;
        
    end;
    
   
else % Unknown type
    
    error('Unknown type');
    
end;





