clear; close; clc;

fs = 22050;         % Audio sample rate

nSamples = 1024;
windowSize = 16;
hopSize = windowSize / 2;
nWindows = nSamples / hopSize;

f0 = 440;           % Fundamental freq
nHarmonics = 20;    % Number of harmonics for additive synth

% Harmonic amplitudes for sawtooth wave
hAmp = 0.8 * ones(1, nHarmonics) ./ (1:nHarmonics);   

tt = (0:1/fs:(1/fs)*(nSamples-1))';         % Plot time

hh = f0 * (1:nHarmonics);           % Harmonic frequencies
xx = sin(2 * pi * tt * hh);         % Columnwise harmonic contributions
xx = xx * diag(hAmp);               % Apply harmonic amplitudes
xx = sum(xx, 2);                    % Sum harmonic contributions

yy = zeros(size(xx));       % Initialize filtered signal

fc = 2 * logspace(1, 3, nWindows/2);      % Filter cutoff freqs. 
fc = [fc, fliplr(fc)];
% fc = linspace(20, 10000, nWindows);

ww = triang(windowSize);    % Triangular window

f = 1;
i = 1;
while i < nSamples-windowSize-1
    
    % Filter design
    df = designfilt('lowpassiir', ...
                'PassbandFrequency', fc(f)/(fs/2), ...
                'FilterOrder', 2);
                
    yy(i:i+windowSize-1) = yy(i:i+windowSize-1) + ww .* filter(df, xx(i:i+windowSize-1));
  
    f = f + 1;          % Next filter cutoff
    i = i + hopSize;    % Next window
    fprintf('i = %d\n', i);
end

%%

figure;
plot(tt, yy, 'LineWidth', 1);

%%
axis off;
print(gcf, 'test2', '-dpdf');



