% firfilt() - Pad data with DC constant, filter data with FIR filter,
%             and shift data by the filter's group delay
%
% Usage:
%   >> EEG = firfilt(EEG, b, lowmem);
%
% Inputs:
%   EEG       - EEGLAB EEG structure
%   b         - vector of filter coefficients
%
% Optional inputs:
%   lowmem    - logical filter channel by channel flag (continuous data
%               only) {default true}
%
% Outputs:
%   EEG   - EEGLAB EEG structure
%
% Note:
%   Setting the lowmem flag to false slightly speeds up filtering of
%   continuous data (in particular for high density recordings), but
%   clearly increases working memory requirements.
%
% Author: Andreas Widmann, University of Leipzig, 2005
%
% See also:
%   filter, findboundaries

%123456789012345678901234567890123456789012345678901234567890123456789012

% Copyright (C) 2005 Andreas Widmann, University of Leipzig, widmann@uni-leipzig.de
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

% $Id$

function EEG = firfilt(EEG, b, lowmem)

if nargin < 2
    error('Not enough input arguments.');
end

if mod(length(b), 2) ~= 1
    error('Filter order is not even.');
end
groupdelay = (length(b) - 1) / 2;

% Continuous data
if EEG.trials == 1

    epochs = findboundaries(EEG.event);
    epochsamples = diff([epochs EEG.pnts + 1]);

    % Split data into cell array of epochs
    EEG.data = mat2cell(EEG.data, EEG.nbchan, epochsamples);

    for epoch = 1:size(EEG.data, 2)

        % Pad data with DC constant
        EEG.data{epoch} = [repmat(EEG.data{epoch}(:, 1), [1 groupdelay]) EEG.data{epoch} repmat(EEG.data{epoch}(:, end), [1 groupdelay])];

        % Lowmem flag
        if nargin == 3 && lowmem == false
            chans = {[1:EEG.nbchan]};
        else
            chans = mat2cell([1:EEG.nbchan], 1, ones(1, EEG.nbchan));
        end

        % Filter the data
        for chan = chans
            EEG.data{epoch}(chan{:}, :) = filter(b, 1, EEG.data{epoch}(chan{:}, :) , [], 2);
        end

        % Remove padding and group delay
        EEG.data{epoch} = EEG.data{epoch}(:, [groupdelay * 2 + 1:end]);

    end

    % Concatenate filtered epochs
    EEG.data = [EEG.data{:}];

% Epoched data
else
    
    % Lowmem flag
    if nargin == 3 && lowmem == false
        EEG.data = {EEG.data};
    else
        EEG.data = mat2cell(EEG.data, EEG.nbchan, EEG.pnts, ones(1, EEG.trials));
    end

    for epoch = 1:length(EEG.data)

        % Pad data with DC constant
        EEG.data{epoch} = [repmat(EEG.data{epoch}(:, 1, :), [1 groupdelay 1]) EEG.data{epoch} repmat(EEG.data{epoch}(:, end, :), [1 groupdelay 1])];

        % Filter the data
        EEG.data{epoch} = filter(b, 1, EEG.data{epoch}, [], 2);

        % Remove padding and group delay
        EEG.data{epoch} = EEG.data{epoch}(:, [groupdelay * 2 + 1:end], :);

    end

    % Concatenate filtered epochs
    EEG.data = cat(3, EEG.data{:});

end
