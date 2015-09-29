clear; close; clc;

nFrames = 50;      % Animation frames
fs = 44100;         % Audio sample rate
f0 = 440;           % Fundamental freq
nHarmonics = 20;    % Number of harmonics for additive synth

% Harmonic amplitudes
hAmp = 0.8 * ones(1, nHarmonics) ./ (1:nHarmonics);   

nCycles = 3;           % Duration in cycles
dur = nCycles / f0;     % Duration in seconds

tt = (0:1/fs:dur)';             % Plot time
xx = zeros(length(tt), 1);      % Audio samples  
for h = 1:nHarmonics
    xx = xx + hAmp(h) * sin(2 * pi * f0 * h * tt);
end

fc = 2 * logspace(1, 4, nFrames);
for f = 1:nFrames
   df(f) = designfilt('lowpassiir', ...
        'PassbandFrequency', fc(f)/(fs/2), ...
        'FilterOrder', 4);
end

% figure('Units', 'Pixels', 'OuterPosition', [100 100 768/2 1024/2]);
for f = 1:nFrames
    
    yy = filter(df(f), xx);
    plot(tt, yy, 'LineWidth', 2);
    axis off;
    ylim([-1.5 1.5]);
    pause(0.05);
%     saveSameSize(gcf, 'format', '-dpng', 'file', sprintf('frames%d', f));
end





