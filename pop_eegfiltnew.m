function [EEG, com] = pop_eegfiltnew(EEG, locutoff, hicutoff, filtorder, revfilt, usefft, plotfreqz)

com = '';

% if nargin < 1
%     help pop_eegfiltnew;
%     return
% end
% if isempty(EEG.data)
%     error('Cannot filter empty dataset.');
% end

% GUI
if nargin < 2

    geometry = {[3, 1], [3, 1], [3, 1], 1, 1};

    uilist = {{'style', 'text', 'string', 'Lower edge of the frequency pass band (Hz)'} ...
              {'style', 'edit', 'string', ''} ...
              {'style', 'text', 'string', 'Higher edge of the frequency pass band (Hz)'} ...
              {'style', 'edit', 'string', ''} ...
              {'style', 'text', 'string', 'FIR Filter order (default is automatic)'} ...
              {'style', 'edit', 'string', ''} ...
              {'style', 'checkbox', 'string', 'Notch filter the data instead of pass band', 'value', 0} ...
              {'style', 'checkbox', 'string', 'Plot frequency response', 'value', 1}};

    result = inputgui('geometry', geometry, 'uilist', uilist, 'title', 'Filter the data -- pop_eegfiltnew()', 'helpcom', 'pophelp(''pop_eegfiltnew'')');

    if isempty(result), return; end

    locutoff = str2double(result{1});
    hicutoff = str2double(result{2});
    filtorder = str2double(result{3});
    revfilt = result{4};
    plotfreqz = result{5};

else
    
    if nargin < 3
        hicutoff = [];
    end
    if nargin < 4
        filtorder = [];
    end
    if nargin < 5 || isempty(revfilt)
        revfilt = 0;
    end
    if nargin > 5 && usefft == 1
        error('FFT filtering not supported. Argument is provided for backward compatibility only.')
    end
    if nargin < 7
        plotfreqz = 0;
    end
    
end

% Constants
TRANSWIDTHRATIO = 0.2;
fNyquist = EEG.srate / 2;

% Check arguments
if locutoff == 0, locutoff = []; end
if hicutoff == 0, hicutoff = []; end
if isempty(hicutoff), revfilt = 1; end
edgeArray = sort([locutoff hicutoff]);

if isempty(edgeArray)
    error('Not enough input arguments.');
end
if any(edgeArray < 0 | edgeArray >= fNyquist)
    error('Cutoff frequency out of range');
end

if ~isempty(filtorder) && (filtorder < 2 || mod(filtorder, 2) ~= 0)
    error('Filter order must be a real, even, positive integer.')
end

% Max stop-band width
stopWidthArray = edgeArray; % Band-/highpass
if revfilt == 0 % Band-/lowpass
    stopWidthArray(end) = fNyquist - edgeArray(end);
elseif length(edgeArray) == 2 % Bandstop
    stopWidthArray = diff(edgeArray) / 2;
end
maxDf = min(stopWidthArray);

% Transition bandwidth and filter order
if isempty(filtorder)

    df = min([(edgeArray * TRANSWIDTHRATIO) maxDf]);

    filtorder = 3.3 / (df / EEG.srate); % Hamming window
    filtorder = ceil(filtorder / 2) * 2; % Filter order must be even.
    
else

    df = 3.3 / filtorder * EEG.srate; % Hamming window
    filtorderMin = ceil(3.3 ./ ([maxDf (maxDf * 2)] / EEG.srate) / 2) * 2;
    if filtorder < filtorderMin(2)
        error('Filter order too low. Minimum filter order is %d. For better results a minimum filter order of %d is recommended.', filtorderMin(2), filtorderMin(1))
    elseif filtorder < filtorderMin(1)
        warning('Transition band is wider than maximum stop-band width. For better results a minimum filter order of %d is recommended.', filtorderMin(1))
    end

end

filterTypeArray = {'lowpass', 'bandpass'; 'highpass', 'bandstop (notch)'};
fprintf('pop_eegfiltnew() - performing %d point %s filtering.\n', filtorder + 1, filterTypeArray{revfilt + 1, length(edgeArray)})
fprintf('pop_eegfiltnew() - transition band width: %.4g Hz\n', df)
fprintf('pop_eegfiltnew() - passband edge(s): %s Hz\n', mat2str(edgeArray))

% Passband edge to cutoff (transition band center; -6 dB)
dfArray = {df, [-df, df]; -df, [df, -df]};
cutoffArray = edgeArray + dfArray{revfilt + 1, length(edgeArray)} / 2;
fprintf('pop_eegfiltnew() - cutoff frequency(ies): %s Hz\n', mat2str(cutoffArray))

% Window
winArray = windows('hamming', filtorder + 1);

% Filter coefficients
if revfilt == 1
    filterTypeArray = {'high', 'stop'};
    b = firws(filtorder, cutoffArray / fNyquist, filterTypeArray{length(cutoffArray)}, winArray);
else
    b = firws(filtorder, cutoffArray / fNyquist, winArray);
end

% Plot frequency response
if plotfreqz
    freqz(b, 1, 2048, EEG.srate);
end

end
