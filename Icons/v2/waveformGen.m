clear; close; clc;

path = '/Users/Jeff/Music/Can/(1971) Tago Mago/01 - Paperhouse.mp3';

[xx, fs] = audioread(path);

xx = sum(xx, 2);
tt = 0:1/fs:(length(xx)/fs-(1/fs));

% df = designfilt('lowpassiir', 'PassbandFrequency', 300/(fs/2), 'FilterOrder', 4);
% xx = filter(df, xx);


startIdx = round(2.6 * fs);
endIdx = round(4.5 * fs);

plot(tt(startIdx:endIdx), xx(startIdx:endIdx));
ylim([-0.6 0.6]);
axis square;
axis off;

print(gcf, 'waveform', '-dpdf');

% soundsc(xx(startIdx:endIdx), fs);

% sizes = [152, 80, 76, 58, 40, 32, 29];
% 
% for s = 1:length(sizes)
%     
%     set(gcf, 'Units', 'Pixels');
%     set(gcf, 'Position', [0 0 sizes(s) sizes(s)]);
%     set(gcf, 'PaperUnits', 'Points');
%     set(gcf, 'PaperSize', [sizes(s) sizes(s)]);
%     saveas(gcf, sprintf('icon_%d.pdf', sizes(s)));
% end





