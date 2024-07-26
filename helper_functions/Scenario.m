classdef Scenario
    properties
        name
        trial
        time
    end
    properties (Dependent)
        participant
        startLane
        streetType

        ped0Label
        ped1Label
        autonOnIdx
        autonOffIdx
        crossedXIdx
        walkingIdx
    end
    methods
        function obj = Scenario(file)
            obj.name = file.name;
            obj.time = file.date;

            filename = fullfile(file.folder, file.name);
            obj.trial = readtable(filename, ReadVariableNames=true, ...
                NumHeaderLines=0, VariableNamingRule="preserve");
        end

        function n = get.participant(obj)
            p = '_([0-9]+)[-\.]';
            r = regexp(obj.name, p, 'tokens', 'once');
            n = str2double(r{1});
        end
        function o = get.startLane(obj)
            p = 'exp_([A-Za-z])';
            r = regexp(obj.name, p, 'tokens', 'once');
            letter = upper(r{1});

            if mod(double(letter) - 65, 6) < 3
                o = 1;
            else
                o = -1;
            end
        end
        function st = get.streetType(obj)
            p = 'exp_([A-Za-z])';
            r = regexp(obj.name, p, 'tokens', 'once');
            letter = upper(r{1});

            if double(letter) - 65 < 6
                st = -1;
            else
                st = 1;
            end
        end

        function l = get.ped0Label(obj)
            l = obj.trial{1, "ped0_val"}{1};
        end
        function l = get.ped1Label(obj)
            l = obj.trial{1, "ped1_val"}{1};
        end
        function i = get.autonOnIdx(obj)
            i = find(obj.trial.("is_autonomous") ~= 0, 1);
        end
        function i = get.autonOffIdx(obj)
            i = obj.autonOnIdx + find(obj.trial{obj.autonOnIdx+1:end, "is_autonomous"} == 0, 1, "first");
        
            if isempty(i)
                i = -1;
            end
        end
        function idx = get.crossedXIdx(obj)
            vehicleLength = 2.8;
        
            for i = obj.autonOnIdx:height(obj.trial)
                vehicleX = obj.trial{i, 'car_x (m)'};
                pedestrianX = abs(obj.trial{i, 'ped0_x (m)'});
        
                if abs(vehicleX - pedestrianX) <= vehicleLength
                    idx = i;
                    return;
                end
            end
        
            idx = -1;
        end            
        function i = get.walkingIdx(obj)
            i = find(obj.trial.("ped0_v (m/s)") ~= 0, 1);
        end
        function rt = getReactionTime(obj, replacementTime)
            if ~exist("replacementTime", "var")
                replacementTime = 0.0;
            end

            if obj.autonOffIdx <= obj.walkingIdx % reacted too early
                rt = replacementTime;
                return
            elseif obj.crossedXIdx > 0 && obj.autonOffIdx > obj.crossedXIdx % reacted too late
                rt = replacementTime;
                return
            end
        
            startTime = obj.trial{obj.walkingIdx, "time (s)"};
            switchTime = obj.trial{obj.autonOffIdx, "time (s)"};
        
            rt = switchTime - startTime;
        end
        function rv = getRelativeValue(obj)
            rv = getScenarioValue(obj.ped0Label, obj.ped1Label);
        end
        function [c, d0, d1] = getChoice(obj)
            if obj.crossedXIdx < 1 || obj.autonOffIdx < 1
                c = 1000;
                d0 = -1;
                d1 = -1;
                return
            end

            endX = obj.trial{obj.crossedXIdx, "car_x (m)"};
            endY = obj.trial{obj.crossedXIdx, "car_y (m)"};

            ped0X = obj.trial{obj.crossedXIdx, "ped0_x (m)"};
            ped0Y = -obj.trial{obj.crossedXIdx, "ped0_y (m)"};

            ped1X = obj.trial{obj.crossedXIdx, "ped1_x (m)"};
            ped1Y = -obj.trial{obj.crossedXIdx, "ped1_y (m)"};

            d0 = sqrt((endX - ped0X)^2 + (endY - ped0Y)^2);
            d1 = sqrt((endX - ped1X)^2 + (endY - ped1Y)^2);

            if d0 > d1
                if obj.getAngle >= 0
                    c = 1;
                else
                    c = -1;
                end
            else
                if obj.getAngle <= 0
                    c = -1;
                else
                    c = 1;
                end
            end
        end
        function x = getGazeData(obj)
            lastIdx = obj.crossedXIdx;
            if obj.crossedXIdx < 1
                lastIdx = height(obj.trial);
            end
            x = obj.trial{obj.walkingIdx:lastIdx, 'gaze_x'};
        end
        function g = getAllGazeData(obj)
            lastIdx = obj.crossedXIdx;
            if obj.crossedXIdx < 1
                lastIdx = height(obj.trial);
            end

            g = obj.trial{1:lastIdx, 'gaze_x'};
        end
        function s = getSteerData(obj)
            lastIdx = obj.crossedXIdx;
            if obj.crossedXIdx < 1
                lastIdx = height(obj.trial);
            end

            firstIdx = obj.autonOffIdx;
            if obj.autonOffIdx < 1 || firstIdx > lastIdx
                firstIdx = obj.walkingIdx + 20;
            end            

            s = obj.trial{firstIdx:lastIdx, ...
                'controller_value_theta (±turn % max 100)'};
        end
        function s = getAllSteerData(obj)
            lastIdx = obj.crossedXIdx;
            if obj.crossedXIdx < 1
                lastIdx = height(obj.trial);
            end

            s = obj.trial{1:lastIdx, ...
                'controller_value_theta (±turn % max 100)'};
        end
        function [mx, mn] = getMinMaxManualSteer(obj)
            steerData = obj.getSteerData();

            mx = max(steerData);
            mn = min(steerData);
        end
        function theta = getAngle(obj)
            if obj.crossedXIdx < 1 || obj.autonOffIdx < 1
                theta = 0;
                return
            end

            raw = obj.trial{obj.crossedXIdx, "car_yaw (degrees)"};
            theta = sign(raw) * 180 - raw;
        end
        function [gd, swap] = getGazeBias(obj)
            begin = obj.walkingIdx;
            if obj.crossedXIdx > 1; finish = obj.crossedXIdx; 
            else; finish = height(obj.trial); end

            ldiff = abs(obj.trial{begin:finish, 'ped0_cx'} - obj.trial{begin:finish, 'gaze_x'});
            rdiff = abs(obj.trial{begin:finish, 'ped1_cx'} - obj.trial{begin:finish, 'gaze_x'});
            dist = ldiff - rdiff;

            gd = mean(dist);

            swap = 0;
            for i = 2:length(dist)
                if sign(dist(i)) ~= sign(i - 1)
                    swap = swap + 1;
                end
            end
        end
        function dt = getDecisionTimeFD(obj, choice, minTime)
            if ~exist("replacementTime", "var")
                minTime = 0.0;
            end
            
            if obj.getReactionTime <= minTime
                dt = 0.0;
                return
            end

            if choice < 0
                [~, steer] = obj.getMinMaxManualSteer;
            elseif choice > 0
                [steer, ~] = obj.getMinMaxManualSteer;
            else
                dt = 0.0;
                return;
            end

            sd = find(obj.getSteerData == steer);
            idx = sd(1);

            dt = obj.trial{idx + obj.autonOffIdx, 'time (s)'} - obj.trial{obj.walkingIdx, 'time (s)'};
        end
        function dt = getDecisionTimeInit(obj, ~, minTime)
            if ~exist("replacementTime", "var")
                minTime = 0.0;
            end
            
            rt = obj.getReactionTime;
            if rt <= minTime
                dt = 0.0;
                return
            end

            sd = obj.getSteerData;
            up = [sd(1); sd];
            down = [sd; sd(end)];
            action = find(abs(up - down) > 0.001);

            if isempty(action)
                dt = rt;
                return
            end

            idx = action(1);

            dt = obj.trial{idx + obj.autonOffIdx, 'time (s)'} - obj.trial{obj.walkingIdx, 'time (s)'};
        end
        function dt = getDecisionTimeInitDir(obj, choice, minTime)
            if ~exist("replacementTime", "var")
                minTime = 0.0;
            end
            
            rt = obj.getReactionTime;
            if rt <= minTime
                dt = 0.0;
                return
            end

            sd = obj.getSteerData;
            up = sd(2:end);
            down = sd(1:end - 1);
            diff = up - down;

            actionTaken = abs(diff) > 0.001;
            correctSide = sign(diff) == sign(choice);

            result = find(actionTaken & correctSide);

            if isempty(result)
                dt = rt;
                return
            end

            try
                idx = result(1);
            catch
                action
            end

            dt = obj.trial{idx + obj.autonOffIdx, 'time (s)'} - obj.trial{obj.walkingIdx, 'time (s)'};
        end
    end
end

