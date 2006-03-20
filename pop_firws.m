% pop_firws() - Filter data using windowed sinc FIR filter
%
% Usage:
%   >> [EEG, com, b] = pop_firws(EEG); % pop-up window mode
%   >> [EEG, com, b] = pop_firws(EEG, 'key1', value1, 'key2', ...
%                                value2, 'keyn', valuen);
%
% Inputs:
%   EEG       - EEGLAB EEG structure
%   'fcutoff' - vector or scalar of cutoff frequency/ies (-6 dB; Hz)
%
% Optional inputs:
%   'ftype'   - char array filter type. {'bandpass'}, 'highpass',
%               {'lowpass'}, or 'bandstop'
%   'forder'  - scalar filter order. Mandatory even {default
%               fix(EEG.srate / min(fcutoff)) * 2, *not* recommended!}
%   'wtype'   - char array window type. 'rectangular', 'bartlett',
%               'hann', 'hamming', {'blackman'}, or 'kaiser'
%   'warg'    - scalar kaiser beta
%
% Outputs:
%   EEG       - filtered EEGLAB EEG structure
%   com       - history string
%   b         - filter coefficients
%
% Note:
%   Window based filters' transition band width is defined by filter
%   order and window type/parameters. Stopband attenuation equals
%   passband ripple and is defined by the window type/parameters. Refer
%   to table below for typical parameters. (Windowed sinc) FIR filters
%   are zero phase in passband when shifted by the filters group delay
%   (what firfilt does). Pi phase jumps noticable in the phase reponse
%   reflect a negative frequency response and only occur in the
%   stopband.
%
%               Beta    Max stopband    Max passband    Max passband    Transition width    Mainlobe width
%                       attenuation     deviation       ripple (dB)     (normalized freq)   (normalized rad freq)
%                       (dB)
%   Rectangular         -21             0.0891          1.552           0.9 / m*             4 * pi / m
%   Bartlett            -25             0.0562          0.977           (2.9** / m)          8 * pi / m
%   Hann                -44             0.0063          0.109           3.1 / m              8 * pi / m
%   Hamming             -53             0.0022          0.038           3.3 / m              8 * pi / m
%   Blackman            -74             0.0002          0.003           5.5 / m             12 * pi / m
%   Kaiser      5.653   -60             0.001           0.017           3.6 / m
%   Kaiser      7.857   -80             0.0001          0.002           5.0 / m
%   * m = filter order
%   ** estimate for higher m only
%
% Author: Andreas Widmann, University of Leipzig, 2005
%
% See also:
%   firfilt, firws, pop_firwsord, pop_kaiserbeta, plotfresp, windows

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

function [EEG, com, b] = pop_firws(EEG, varargin)

    com = '';
    if nargin < 1
        help pop_firws;
        return;
    end
    if isempty(EEG.data)
        error('Cannot process empty dataset');
    end

    if nargin < 2
        drawnow;
        ftypes = {'bandpass' 'highpass' 'lowpass' 'bandstop'};
        wtypes = {'rectangular' 'bartlett' 'hann' 'hamming' 'blackman' 'kaiser'};
        uigeom = {[1 0.75 0.75] [1 0.75 0.75] [1] [1 0.75 0.75] [1 0.75 0.75] [1 0.75 0.75] [1] [1 0.75 0.75]};
        uilist = {{'style' 'text' 'string' 'Cutoff frequency(ies) [hp lp] (-6 dB; Hz):'} ...
                  {'style' 'edit' 'string' '' 'tag' 'fcutoffedit'} {} ...
                  {'style' 'text' 'string' 'Filter type:'} ...
                  {'style' 'popupmenu' 'string' ftypes 'tag' 'ftypepop'} {} ...
                  {} ...
                  {'style' 'text' 'string' 'Window type:'} ...
                  {'style' 'popupmenu' 'string' wtypes 'tag' 'wtypepop' 'value' 5 'callback' @comwtype} {} ...
                  {'style' 'text' 'string' 'Kaiser window beta:' 'tag' 'wargtext' 'enable' 'off'} ...
                  {'style' 'edit' 'string' '' 'tag' 'wargedit' 'enable' 'off'} ...
                  {'style' 'pushbutton' 'string' 'Estimate' 'tag' 'wargpush' 'enable' 'off' 'callback' @comwarg} ...
                  {'style' 'text' 'string' 'Filter order (mandatory even):'} ...
                  {'style' 'edit' 'string' '' 'tag' 'forderedit'} ...
                  {'style' 'pushbutton' 'string' 'Estimate' 'callback' {@comforder, wtypes, EEG.srate}} ...
                  {'style' 'edit' 'tag' 'devedit' 'visible' 'off'} ...
                  {} {} {'Style' 'pushbutton' 'string', 'Plot filter responses' 'callback' {@comfresp, wtypes, ftypes, EEG.srate}}};
        result = inputgui(uigeom, uilist, 'pophelp(''pop_firws'')', 'Filter the data -- pop_firws()');

        if length(result) == 0, return; end
        args = {};
        if ~isempty(result{1})
            args = [args {'fcutoff'} {str2num(result{1})}];
        end
        args = [args {'ftype'} ftypes(result{2})];
        args = [args {'wtype'} wtypes(result{3})];
        if ~isempty(result{4})
            args = [args {'warg'} {str2num(result{4})}];
        end
        if ~isempty(result{5})
            args = [args {'forder'} {str2num(result{5})}];
        end
    else
        args = varargin;
    end

    % Convert args to structure
    args = struct(args{:});

    c = parseargs(args, EEG.srate);
    b = firws(c{:});

    % Filter
    disp('pop_firws() - filtering the data');
    EEG = firfilt(EEG, b);

    % History string
    com = sprintf('%s = pop_firws(%s', inputname(1), inputname(1));
    for c = fieldnames(args)'
        if ischar(args.(c{:}))
            com = [com sprintf(', ''%s'', ''%s''', c{:}, args.(c{:}))];
        else
            com = [com sprintf(', ''%s'', %s', c{:}, mat2str(args.(c{:})))];
        end
    end
    com = [com ');'];

% Convert structure args to cell array firws parameters
function c = parseargs(args, srate)

    % Cutoff frequencies
    if ~isfield(args, 'fcutoff') || isempty(args.fcutoff)
        error('Not enough input arguments.');
    end
    args.fcutoff = sort(args.fcutoff / (srate / 2)); % Sorting and normalization

    % Filter order
    if ~isfield(args, 'forder') || isempty(args.forder)
        args.forder = fix(1 / min(args.fcutoff)) * 4; % Default, not recommended!
    end
    c = [{args.forder} {args.fcutoff}];

    % Filter type
    if isfield(args, 'ftype')  && ~isempty(args.ftype)
        if (strcmpi(args.ftype, 'bandpass') || strcmpi(args.ftype, 'bandstop')) && length(args.fcutoff) ~= 2
            error('Not enough input arguments.');
        elseif (strcmpi(args.ftype, 'highpass') || strcmpi(args.ftype, 'lowpass')) && length(args.fcutoff) ~= 1
            error('Too many input arguments.');
        end
        switch args.ftype
            case 'bandstop'
                c = [c {'stop'}];
            case 'highpass'
                c = [c {'high'}];
        end
    end

    % Window type
    if isfield(args, 'wtype')  && ~isempty(args.wtype)
        if isfield(args, 'warg')  && ~isempty(args.warg)
            c = [c {windows(args.wtype, args.forder + 1, args.warg)'}];
        else
            c = [c {windows(args.wtype, args.forder + 1)'}];
        end
    end

% Callback popup menu window type
function comwtype(varargin)
    if get(varargin{1}, 'value') == 6
        enable = 'on';
    else
        enable = 'off';
    end
    set(findobj(gcbf, 'tag', 'wargtext'), 'enable', enable);
    set(findobj(gcbf, 'tag', 'wargedit'), 'enable', enable);
    set(findobj(gcbf, 'tag', 'wargpush'), 'enable', enable);

% Callback estimate Kaiser beta
function comwarg(varargin)
    [warg, dev] = pop_kaiserbeta;
    set(findobj(gcbf, 'tag', 'wargedit'), 'string', warg);
    set(findobj(gcbf, 'tag', 'devedit'), 'string', dev);

% Callback estimate filter order
function comforder(obj, evt, wtypes, srate)
    wtype = wtypes{get(findobj(gcbf, 'tag', 'wtypepop'), 'value')};
    dev = get(findobj(gcbf, 'tag', 'devedit'), 'string');
    [forder, dev] = pop_firwsord(wtype, srate, [], dev);
    set(findobj(gcbf, 'tag', 'forderedit'), 'string', forder);
    set(findobj(gcbf, 'tag', 'devedit'), 'string', dev);

% Callback plot filter responses
function comfresp(obj, evt, wtypes, ftypes, srate)
    args.fcutoff = str2num(get(findobj(gcbf, 'tag', 'fcutoffedit'), 'string'));
    args.ftype = ftypes{get(findobj(gcbf, 'tag', 'ftypepop'), 'value')};
    args.wtype = wtypes{get(findobj(gcbf, 'tag', 'wtypepop'), 'value')};
    args.warg = str2num(get(findobj(gcbf, 'tag', 'wargedit'), 'string'));
    args.forder = str2num(get(findobj(gcbf, 'tag', 'forderedit'), 'string'));
    c = parseargs(args, srate);
    b = firws(c{:});
    H = findobj('tag', 'filter responses', 'type', 'figure');
    if ~isempty(H)
        figure(H);
    else
        H = figure;
        set(H, 'color', [.93 .96 1], 'tag', 'filter responses');
    end
    plotfresp(b, 1, [], srate);
