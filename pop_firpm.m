% pop_firpm() - Filter data using Parks-McClellan FIR filter
%
% Usage:
%   >> [EEG, com, b] = pop_firpm(EEG); % pop-up window mode
%   >> [EEG, com, b] = pop_firpm(EEG, 'key1', value1, 'key2', ...
%                                value2, 'keyn', valuen);
%
% Inputs:
%   EEG       - EEGLAB EEG structure
%   'fcutoff' - vector or scalar of cutoff frequency/ies (~-6 dB; Hz)
%   'ftrans'  - scalar transition band width
%   'ftype'   - char array filter type. 'bandpass', 'highpass',
%               'lowpass', or 'bandstop'
%   'forder'  - scalar filter order. Mandatory even
%
% Optional inputs:
%   'wtpass'  - scalar passband weight
%   'wtstop'  - scalar stopband weight
%
% Outputs:
%   EEG       - filtered EEGLAB EEG structure
%   com       - history string
%   b         - filter coefficients
%
% Note:
%   Requires the signal processing toolbox.
%
% Author: Andreas Widmann, University of Leipzig, 2005
%
% See also:
%   firfilt, pop_firpmord, plotfresp, firpm, firpmord

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

function [EEG, com, b] = pop_firpm(EEG, varargin)

    if exist('firpm') ~= 2
       error('Requires the signal processing toolbox.');
    end

    com = '';
    if nargin < 1
        help pop_firpm;
        return;
    end
    if isempty(EEG.data)
        error('Cannot process empty dataset');
    end

    if nargin < 2
        drawnow;
        ftypes = {'bandpass' 'highpass' 'lowpass' 'bandstop'};
        uigeom = {[1 0.75 0.75] [1 0.75 0.75] [1 0.75 0.75] [1] [1 0.75 0.75] [1 0.75 0.75] [1 0.75 0.75] [1] [1 0.75 0.75]};
        uilist = {{'style' 'text' 'string' 'Cutoff frequency(ies) [hp lp] (~-6 dB; Hz):'} ...
                  {'style' 'edit' 'string' '' 'tag' 'fcutoffedit'} {} ...
                  {'style' 'text' 'string' 'Transition band width:'} ...
                  {'style' 'edit' 'string' '' 'tag' 'ftransedit'} {} ...
                  {'style' 'text' 'string' 'Filter type:'} ...
                  {'style' 'popupmenu' 'string' ftypes 'tag' 'ftypepop'} {} ...
                  {} ...
                  {'style' 'text' 'string' 'Passband weight:'} ...
                  {'style' 'edit' 'string' '' 'tag' 'wtpassedit'} {} ...
                  {'style' 'text' 'string' 'Stopband weight:'} ...
                  {'style' 'edit' 'string' '' 'tag' 'wtstopedit'} {} ...
                  {'style' 'text' 'string' 'Filter order (mandatory even):'} ...
                  {'style' 'edit' 'string' '' 'tag' 'forderedit'} ...
                  {'style' 'pushbutton' 'string' 'Estimate' 'tag' 'orderpush' 'callback' {@comcb, ftypes, EEG.srate}} ...
                  {} ...
                  {} {} {'Style' 'pushbutton' 'string', 'Plot filter responses' 'tag' 'plotpush' 'callback' {@comcb, ftypes, EEG.srate}}};
        result = inputgui(uigeom, uilist, 'pophelp(''pop_firpm'')', 'Filter the data -- pop_firpm()');
        if length(result) == 0, return; end

        args = {};
        if ~isempty(result{1})
            args = [args {'fcutoff'} {str2num(result{1})}];
        end
        if ~isempty(result{2})
            args = [args {'ftrans'} {str2num(result{2})}];
        end
        args = [args {'ftype'} ftypes(result{3})];
        if ~isempty(result{4})
            args = [args {'wtpass'} {str2num(result{4})}];
        end
        if ~isempty(result{5})
            args = [args {'wtstop'} {str2num(result{5})}];
        end
        if ~isempty(result{6})
            args = [args {'forder'} {str2num(result{6})}];
        end
    else
        args = varargin;
    end

    % Convert args to structure
    args = struct(args{:});

    c = parseargs(args, EEG.srate);
    if ~isfield(args, 'forder') | isempty(args.forder)
        error('Not enough input arguments');
    end
    b = firpm(args.forder, c{:});

    % Filter
    disp('pop_firpm() - filtering the data');
    EEG = firfilt(EEG, b);

    % History string
    com = sprintf('%s = pop_firpm(%s', inputname(1), inputname(1));
    for c = fieldnames(args)'
        if ischar(args.(c{:}))
            com = [com sprintf(', ''%s'', ''%s''', c{:}, args.(c{:}))];
        else
            com = [com sprintf(', ''%s'', %s', c{:}, mat2str(args.(c{:})))];
        end
    end
    com = [com ');'];

% Convert structure args to cell array firpm parameters
function c = parseargs(args, srate)

    if ~isfield(args, {'fcutoff', 'ftype', 'ftrans'}) | isempty(args.fcutoff) | isempty(args.ftype) | isempty(args.ftrans)
        error('Not enough input arguments.');
    end

    % Cutoff frequencies
    args.fcutoff = [args.fcutoff - args.ftrans / 2 args.fcutoff + args.ftrans / 2];
    args.fcutoff = sort(args.fcutoff / (srate / 2)); % Sorting and normalization
    if any(args.fcutoff <= 0)
        error('Cutoff frequencies - transition band width / 2 must not be <= DC');
    elseif any(args.fcutoff >= 1)
        error('Cutoff frequencies + transition band width / 2 must not be >= Nyquist');
    end
    c = {[0 args.fcutoff 1]};

    % Filter type
    switch args.ftype
        case 'bandpass'
            c = [c {[0 0 1 1 0 0]}];
        case 'bandstop'
            c = [c {[1 1 0 0 1 1]}];
        case 'highpass'
            c = [c {[0 0 1 1]}];
        case 'lowpass'
            c = [c {[1 1 0 0]}];
    end

    %Filter weights
    if isfield(args, {'wtpass', 'wtstop'}) & ~isempty(args.wtpass) & ~isempty(args.wtstop)
        w = [args.wtstop args.wtpass];
        c{3} = w(c{2}(1:2:end) + 1);
    end

% Callback
function comcb(obj, evt, ftypes, srate)

    args.fcutoff = str2num(get(findobj(gcbf, 'tag', 'fcutoffedit'), 'string'));
    args.ftype = ftypes{get(findobj(gcbf, 'tag', 'ftypepop'), 'value')};
    args.ftrans = str2num(get(findobj(gcbf, 'tag', 'ftransedit'), 'string'));
    args.wtpass = str2num(get(findobj(gcbf, 'tag', 'wtpassedit'), 'string'));
    args.wtstop = str2num(get(findobj(gcbf, 'tag', 'wtstopedit'), 'string'));
    c = parseargs(args, srate);

    switch get(gcbo, 'tag')
        case 'orderpush'
            [args.forder, args.wtpass, args.wtstop] = pop_firpmord(c{1}(2:end - 1), c{2}(1:2:end));
            set(findobj(gcbf, 'tag', 'forderedit'), 'string', ceil(args.forder / 2) * 2);
            set(findobj(gcbf, 'tag', 'wtpassedit'), 'string', args.wtpass);
            set(findobj(gcbf, 'tag', 'wtstopedit'), 'string', args.wtstop);

        case 'plotpush'
            args.forder = str2num(get(findobj(gcbf, 'tag', 'forderedit'), 'string'));
            if isempty(args.forder)
                error('Not enough input arguments');
            end
            b = firpm(args.forder, c{:});
            H = findobj('tag', 'filter responses', 'type', 'figure');
            if ~isempty(H)
                figure(H);
            else
                H = figure;
                set(H, 'color', [.93 .96 1], 'tag', 'filter responses');
            end
            plotfresp(b, 1, [], srate);
    end
