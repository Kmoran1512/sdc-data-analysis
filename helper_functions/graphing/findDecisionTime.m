function findDecisionTime(allData, choices)
    nTrials = length(allData);

    startLane = zeros(nTrials, 1);
    streetType = zeros(nTrials, 1);
    absValue = zeros(nTrials, 1);

    dtsmax = zeros(nTrials, 1);
    dtsinit = zeros(nTrials, 1);
    dtsDirInit = zeros(nTrials, 1);


    rts = zeros(nTrials, 1);

    for t = 1:nTrials
        startLane(t) = allData(t).startLane;
        streetType(t) = allData(t).streetType;

        absValue(t) = abs(allData(t).getRelativeValue());
        dtsmax(t) = allData(t).getDecisionTimeFD(choices(t));
        dtsinit(t) = allData(t).getDecisionTimeInit(choices(t));
        dtsDirInit(t) = allData(t).getDecisionTimeInitDir(choices(t));

        rts(t) = allData(t).getReactionTime();

    end

    corrColumns = [startLane, streetType, choices, absValue, dtsmax, dtsinit, dtsDirInit];
    columnHeading = {
        'Start Lane', 'Street Type', 'Choices', '|\Delta_\nu|', 'Decision Time (From Max)', 'Decision Time (From any steer)', 'Decision Time (From Direction)'
    };

    goodDecision = rts > 0.2;
    simpleOutliersRemoved = corrColumns(goodDecision, :);

    choiceMade = sign(choices) ~= sign(startLane);    
    switchOutliersRemoved = corrColumns(goodDecision & choiceMade, :);

    graphCorr(simpleOutliersRemoved, columnHeading);
    graphCorr(switchOutliersRemoved, columnHeading);

end

function graphCorr(corrColumns, columnHeadings)
    R = corrcoef(corrColumns);

    figure;
    imagesc(R)
    colorbar
    colormap(jet)
    axis square;
    [nrows, ncols] = size(R);
    for i = 1:nrows
        for j = 1:ncols
            text(j, i, num2str(R(i,j),'%0.2f'), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'Color', 'k', 'FontSize', 8);
        end
    end
    xticks(1:ncols);
    xticklabels(columnHeadings);
    
    yticks(1:nrows);
    yticklabels(columnHeadings);
end


function simpleCategoryPlot(categories, data)
    [p, ~, stats] = anova1(data, categories);

    figure;
    lr = fitlm(categories, data);
    plot(lr);

%    if p < 0.05
%        multcompare(stats)
%    end
end