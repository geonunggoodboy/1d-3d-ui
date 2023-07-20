%
%--------------------------------------------------------------------------
% File Name: plot_module_v_1_3.m
%
% Description: Show 1D/3D UI about Radar Data
% Version: 1.3
% Autuher: GeonUng Lee
% Email: dlrjsdndf@gmail.com
%
%--------------------------------------------------------------------------
%

classdef plot_module_v_1_3 < handle
    properties (Access = private)
        % for 1D UI
        fig_1d
        fig_r1
        fig_r2
        fig_r3
        distance_table
        buffer_mobile_1d
        start_time_1d
        
        % for 3D UI
        fig_3d
        pos_table
        buffer_mobile_3d
        start_time_3d
    end
    properties
        max_radar_num
        max_tag_num
        max_distance
        data
    end
    
    methods (Access = public)
        %--------------------------------------------------------------------------
        % Initial setting for plot module
        %--------------------------------------------------------------------------
        function obj = plot_module_v_1_3(max_radar_num, max_tag_num, max_distance)
            obj.max_radar_num = max_radar_num;
            obj.max_tag_num = max_tag_num;
            obj.max_distance = max_distance;
            obj = create_figure_1d(obj);
            obj = create_figure_3d(obj);
            obj = create_distance_table(obj);
            obj = create_pos_table(obj);
            obj = create_buffer_mobile_1d(obj);
            obj = create_buffer_mobile_3d(obj);
            obj.data = [];
        end
        
        %--------------------------------------------------------------------------
        % Data structures to be used in the module
        %--------------------------------------------------------------------------
        function obj = add_data(obj, radar_num, f_m, distance, SNR, mobile)
            ui_data.radar = radar_num; 
            ui_data.id = f_m;
            ui_data.fm = f_m;
            ui_data.distance = distance;
            ui_data.SNR = SNR;
            ui_data.mobile = mobile;
            obj.data = [obj.data ui_data];
            obj = update_distance_table(obj);
        end 

        %--------------------------------------------------------------------------
        % Save 1D History to buffer
        %--------------------------------------------------------------------------
        function obj = save_1d_his(obj)
            current_time = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
            if length(obj.buffer_mobile_1d(1, :)) == 1
                obj.buffer_mobile_1d{1, end+1} = 0;
                obj.start_time_1d = current_time;
            else
                ms = current_time - obj.start_time_1d;
                obj.buffer_mobile_1d{1, end+1} = milliseconds(ms);
            end
            
            % distance table에서 추출
            for row_dis = 2:obj.max_tag_num+1
                tag_id = row_dis - 1;
                start_row = tag_id * 3 - 1; 
                % buffer에 저장
                if obj.distance_table{row_dis, end}
                    for row_buf = start_row:start_row+2
                        obj.buffer_mobile_1d{row_buf, end} = obj.distance_table{row_dis, row_buf - start_row + 2};
                    end
                end
            end
        end

        %--------------------------------------------------------------------------
        % Calculate 3D Pos by using distance_table and update buffer_mobile_3d 
        %--------------------------------------------------------------------------
        function obj = cal_pos(obj)
            pos_radars = [100 0 0; 0 100 0; 0 0 100]; % Radar positions
            
            current_time = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
            temp_table = obj.distance_table(~all(cellfun('isempty', obj.distance_table(1:end, 2:4)),2),:);

            if length(obj.buffer_mobile_3d(1, :)) == 1
                obj.buffer_mobile_3d{1, end+1} = 0;
                obj.start_time_3d = current_time;
            else
                ms = current_time - obj.start_time_3d;
                obj.start_time_3d = current_time;
                obj.buffer_mobile_3d{1, end+1} = milliseconds(ms);
            end
            
            for index = 2:length(temp_table(:, 1))
                if isempty(temp_table{index, 2}) || isempty(temp_table{index, 3}) || isempty(temp_table{index, 4})
                    continue
                end
                r = [temp_table{index, 2}, temp_table{index, 3}, temp_table{index, 4}]; % Distances from radars
                is_mobile = temp_table{index, end};
        
                ex = (pos_radars(2, :) - pos_radars(1, :)) / norm(pos_radars(2, :) - pos_radars(1, :));
                i = dot(ex, pos_radars(3, :) - pos_radars(1, :));
                ey = (pos_radars(3, :) - pos_radars(1, :) - i*ex) / norm(pos_radars(3, :) - pos_radars(1, :) - i*ex);
                ez = cross(ex, ey);
                d = norm(pos_radars(2, :) - pos_radars(1, :));
                j = dot(ey, pos_radars(3, :) - pos_radars(1, :));
        
                x = (r(1)^2 - r(2)^2 + d^2) / (2*d);
                y = ((r(1)^2 - r(3)^2 + i^2 + j^2) / (2*j)) - ((i/j)*x);
                z = sqrt(max(0, r(1)^2 - x^2 - y^2));
        
                if dot([x y z], ez) < 0  % if z is negative
                    z = -z;
                end
        
                triPt = pos_radars(1, :) + x*ex + y*ey + z*ez;
        
                temp_id = str2double(temp_table{index, 1}) + 1;
                obj.pos_table{temp_id, 2} = triPt(1);
                obj.pos_table{temp_id, 3} = triPt(2);
                obj.pos_table{temp_id, 4} = triPt(3);
                obj.pos_table{temp_id, 5} = is_mobile;
                if is_mobile
                    obj.buffer_mobile_3d{temp_id*3-4, end} = triPt(1);
                    obj.buffer_mobile_3d{temp_id*3-3, end} = triPt(2);
                    obj.buffer_mobile_3d{temp_id*3-2, end} = triPt(3);
                end
            end 
        end

        %--------------------------------------------------------------------------
        % Plot 1D
        %--------------------------------------------------------------------------
        function obj = plot_1d(obj)
            % create temp_table
            temp_table = obj.distance_table(~all(cellfun('isempty', obj.distance_table(1:end, 2:4)),2 ), :);
            distance_uit = findall(obj.fig_1d, 'Tag', 'distance_uit');
            distance_uit.Data = temp_table;

            % plot graph by radar
            ax1 = findall(obj.fig_1d, 'Type', 'axes', 'Tag', 'ax1');
            ax2 = findall(obj.fig_1d, 'Type', 'axes', 'Tag', 'ax2');
            ax3 = findall(obj.fig_1d, 'Type', 'axes', 'Tag', 'ax3');

            for radar_num = 1:obj.max_radar_num
                for index_tag = 2:length(temp_table(:, 1))
                    if temp_table{index_tag, radar_num + 1}
                        tag_id = str2double(temp_table{index_tag, 1});
                        tag_distance = temp_table{index_tag, radar_num + 1};
                        switch radar_num
                            case 1
                                stem(ax1, tag_distance, tag_id, "LineStyle",":","Marker", ".", "MarkerSize", 15);
                                hold(ax1, 'on');
                            case 2
                                stem(ax2, tag_distance, tag_id, "LineStyle",":","Marker", ".", "MarkerSize", 15);
                                hold(ax2, 'on');
                            case 3
                                stem(ax3, tag_distance, tag_id, "LineStyle",":","Marker", ".", "MarkerSize", 15);
                                hold(ax3, 'on');
                        end
                    end
                end
                hold(ax1, "off");
                hold(ax2, "off");
                hold(ax3, "off");
            end

            % In the plot_1d method, after the create_radar_figure call      
            update_radar_figure(obj);

            drawnow;
        end   

        %--------------------------------------------------------------------------
        % Plot 3D
        %--------------------------------------------------------------------------
        function plot_3d(obj)
            % temp_table
            temp_table = obj.pos_table(~all(cellfun('isempty', obj.pos_table(1:end, 2:end)),2), :);

            % get UI
            pos_uit = findall(obj.fig_3d, 'Tag', 'pos_uit');
            ax_3d = findall(obj.fig_3d, 'Tag', 'ax_3d');

            % set table
            pos_uit.Data = temp_table;

            % plot new graph
            for index = 2:length(temp_table(:, 1))
                [temp_id, temp_x, temp_y, temp_z, temp_mobile] = temp_table{index, :};
                if temp_mobile
                    plot3(ax_3d, temp_x, temp_y, temp_z, 's', 'DisplayName', temp_id);
                    hold(ax_3d, 'on');
                else
                    plot3(ax_3d, temp_x, temp_y, temp_z, 'o', 'DisplayName', temp_id);
                    hold(ax_3d, 'on');
                end
            end
            legend(ax_3d,'Location', 'best');
            hold(ax_3d, 'off');
            drawnow;
        end
    end

    methods (Access = private)
        %--------------------------------------------------------------------------
        % Update Distance Table
        %--------------------------------------------------------------------------
        function obj = update_distance_table(obj)
            for index = 1:length(obj.data)
                temp_id = obj.data(index).id + 1;
                temp_col = obj.data(index).radar + 1;
                temp_distance = obj.data(index).distance;
                temp_SNR = obj.data(index).SNR;
                temp_mobile = obj.data(index).mobile;
                obj.distance_table{temp_id, temp_col} = temp_distance;
                obj.distance_table{temp_id, 4 + obj.data(index).radar} = temp_SNR;
                obj.distance_table{temp_id, end} = temp_mobile;
            end
        end
        %--------------------------------------------------------------------------
        % Create tables and buffer
        %--------------------------------------------------------------------------
        function obj = create_distance_table(obj)
            % Create fundamental distance table form
            obj.distance_table = cell(obj.max_tag_num, 1);
            obj.distance_table{1, 1} = 'ID\Radar';
            for col = 2:obj.max_radar_num+1
                obj.distance_table{1, col} = ['Radar' num2str(col-1)];
            end
            obj.distance_table{1, 5} = 'SNR1';
            obj.distance_table{1, 6} = 'SNR2';
            obj.distance_table{1, 7} = 'SNR3';
            obj.distance_table{1, 8} = 'Mobile';
            for row = 2:obj.max_tag_num + 1
                obj.distance_table{row, 1} = num2str(row -1);
            end 
        end

        function obj = create_pos_table(obj)
            % Create fundamental pos table form
            obj.pos_table = cell(obj.max_tag_num, 5);
            obj.pos_table{1,1} = 'Id\Pos(m)';
            obj.pos_table{1,2} = 'X';
            obj.pos_table{1,3} = 'Y';
            obj.pos_table{1,4} = 'Z';
            obj.pos_table{1,5} = 'Mobile';
            for row = 2:obj.max_tag_num+1
                obj.pos_table{row, 1} = num2str(row - 1);
            end
        end

        function obj = create_buffer_mobile_1d(obj)
            obj.buffer_mobile_1d = cell((obj.max_tag_num+1)*3, 1);
            obj.buffer_mobile_1d{1, 1} = 'ID/Time';
            for row = 2:(obj.max_tag_num+1)*3
                obj.buffer_mobile_1d{row, 1} = num2str(floor((row-2)/3)+1);   
            end
        end

        function obj = create_buffer_mobile_3d(obj)
            obj.buffer_mobile_3d = cell((obj.max_tag_num+1)*3, 1);
            obj.buffer_mobile_3d{1, 1} = 'ID/Time';
            for row = 2:(obj.max_tag_num+1)*3
                obj.buffer_mobile_3d{row, 1} = num2str(floor((row-2)/3)+1);
            end
        end

        %--------------------------------------------------------------------------
        % Create fundamental 1D UI form
        %--------------------------------------------------------------------------
        function obj = create_figure_1d(obj)
            % set fig_1d
            obj.fig_1d = uifigure('Tag', 'Fig_1d', 'Name', '1D UI');
            obj.fig_1d.Position(1:2) = [800 500];
            obj.fig_1d.Position(3:4) = [720 600];

            % for btn
            btn_width = 100;
            margin = 20;
            total_spacing = obj.fig_1d.Position(3) - 2*margin - 4*btn_width;
            btn_spacing = total_spacing/3;
            
            start_x = margin;
            btn_valid = uibutton(obj.fig_1d, 'Position', [start_x 20 btn_width 20], 'Text', 'Show Data#', 'Tag', 'btn_valid');
            
            start_x = start_x + btn_width + btn_spacing;
            btn_r1 = uibutton(obj.fig_1d, 'Position', [start_x 20 btn_width 20], 'Text', 'Radar1', 'Tag', 'btn_r1');

            start_x = start_x + btn_width + btn_spacing;
            btn_r2 = uibutton(obj.fig_1d, 'Position', [start_x 20 btn_width 20], 'Text', 'Radar2', 'Tag', 'btn_r2');
            
            start_x = start_x + btn_width + btn_spacing;
            btn_r3 = uibutton(obj.fig_1d, 'Position', [start_x 20 btn_width 20], 'Text', 'Radar3', 'Tag', 'btn_r3');

            % Create ax_1des for radar graph
            ax_radars = gobjects(obj.max_radar_num, 1);
            for radar_num = 1:obj.max_radar_num
                ax_radars(radar_num) = uiaxes(obj.fig_1d, 'Tag', ['ax' num2str(radar_num)]);
                ax_radars(radar_num).Position(1) = 360;
                ax_radars(radar_num).Position(2) = 600 - 180 * radar_num;
                ax_radars(radar_num).Position(3) = 360;
                ax_radars(radar_num).Position(4) = 180;
                ax_radars(radar_num).Title.String = ['Radar ' num2str(radar_num)];
                ax_radars(radar_num).TitleFontWeight = 'bold';
                xlabel(ax_radars(radar_num), 'Distance');
                ylabel(ax_radars(radar_num), 'TAG_ID');
                xlim(ax_radars(radar_num), [0 obj.max_distance]);
                ylim(ax_radars(radar_num), [0 obj.max_tag_num]);
                grid(ax_radars(radar_num), 'on');
            end        

            % Create a space to use when presenting the distance table
            distance_uit = uitable(obj.fig_1d, 'Tag', 'distance_uit');
            distance_uit.Data = obj.distance_table;
            distance_uit.Position(3) = 320;
            distance_uit.Position(2) = 160;
            distance_uit.Position(1) = 20;
            distance_uit.ColumnEditable = false;
            distance_uit.ColumnName = [];
            distance_uit.RowName = [];

            btn_valid.ButtonPushedFcn = @(~, ~) show_dis_table(obj, btn_valid);
            btn_r1.ButtonPushedFcn = @(~, ~) create_radar_figure(obj, 1);
            btn_r2.ButtonPushedFcn = @(~, ~) create_radar_figure(obj, 2);
            btn_r3.ButtonPushedFcn = @(~, ~) create_radar_figure(obj, 3);
        end

        %--------------------------------------------------------------------------
        % Create fundamental 3D UI form
        %--------------------------------------------------------------------------
        function obj = create_figure_3d(obj)
            % Create UI figure_3d
            obj.fig_3d = uifigure('Name', '3D UI');
            obj.fig_3d.Position(3:4) = [720 600];
            
            % Create button at the bottom
            btn_valid = uibutton(obj.fig_3d, 'Position', [20 20 100 20], 'Text', 'Show Data#', 'Tag', 'btn_valid');
            btn_history = uibutton(obj.fig_3d, 'Position', [obj.fig_3d.Position(3)-120 20 100 20], 'Text', 'Show History', 'Tag', 'btn_history');
            tag_show = uieditfield(obj.fig_3d, 'numeric', 'Position', [obj.fig_3d.Position(3)-240 20 100 20], 'Tag', 'tag_show');

            % Create pos table
            pos_uit_3d = uitable(obj.fig_3d, 'Tag', 'pos_uit');
            pos_uit_3d.Position(3) = 320;
            pos_uit_3d.Position(2) = 160;
            pos_uit_3d.Position(1) = 20;

            % Assign header names
            pos_uit_3d.ColumnEditable = false;
            pos_uit_3d.ColumnName = [];
            pos_uit_3d.RowName = [];

            % Create Position 3D graph
            ax_3d = uiaxes(obj.fig_3d, 'Tag', 'ax_3d');
            ax_3d.Title.String = '3D UI';
            ax_3d.Position(1) = 360;
            ax_3d.Position(2) = 180;
            ax_3d.Position(3) = 360;
            ax_3d.Position(4) = 300;
            ax_3d.XLabel.String = 'X Pos';
            ax_3d.YLabel.String = 'Y Pos';
            ax_3d.ZLabel.String = 'Z Pos';
            ax_3d.XLim = [0 obj.max_distance];
            ax_3d.YLim = [0 obj.max_distance];
            ax_3d.ZLim = [0 obj.max_distance];
            grid(ax_3d, 'on');

            btn_valid.ButtonPushedFcn = @(~, ~) show_pos_table(obj, btn_valid);
            btn_history.ButtonPushedFcn = @(~, ~) show_history_3d(obj, tag_show.Value);
        end
        
        %--------------------------------------------------------------------------
        % button event for btn_valid
        % 1. used in ditance_table
        % 2. used in pos_table
        %--------------------------------------------------------------------------
        function show_dis_table(obj, btn_valid)
            % Toggle the button's text
            distance_uit = findall(obj.fig_1d, 'Tag', 'distance_uit');
            if strcmp(btn_valid.Text, 'Show Data#')
                btn_valid.Text = 'Hide Data#';
        
                % Get the data from the table
                temp_data = distance_uit.Data;
                
                % Count the number of valid values in each row
                validCounts = sum(~cellfun(@isempty, temp_data(2:end, 2:4)), 2);
            
                % Define the styles
                s1 = uistyle('BackgroundColor', "#F77A8F");  % Red for 1 valid value
                s2 = uistyle('BackgroundColor', "#EDB120");  % Yellow for 2 valid values
                s3 = uistyle('BackgroundColor', "#77AC30");  % Green for 3 valid values
                
                % Apply the styles based on the number of valid values
                for row = 1:size(validCounts, 1)
                    if validCounts(row) == 1
                        addStyle(distance_uit, s1, 'cell', [row+1, 1]);
                    elseif validCounts(row) == 2
                        addStyle(distance_uit, s2, 'cell', [row+1, 1]);
                    elseif validCounts(row) == 3
                        addStyle(distance_uit, s3, 'cell', [row+1, 1]);
                    end
                end
            else
                btn_valid.Text = 'Show Data#';
                removeStyle(distance_uit);
            end
        end

        function show_pos_table(obj, btn_valid)
            pos_uit = findall(obj.fig_3d, 'Tag', 'pos_uit');
            if strcmp(btn_valid.Text, 'Show Data#')
                btn_valid.Text = 'Hide Data#';
                
                % Get the data from the table
                temp_data = pos_uit.Data;
                
                % Count the number of valid values in each row
                validCounts = sum(~cellfun(@isempty, temp_data(2:end, 2:4)), 2);
            
                % Define the styles
                s1 = uistyle('BackgroundColor', "#F77A8F");  % Red for 1 valid value
                s2 = uistyle('BackgroundColor', "#EDB120");  % Yellow for 2 valid values
                s3 = uistyle('BackgroundColor', "#77AC30");  % Green for 3 valid values
                
                % Apply the styles based on the number of valid values
                for row = 1:size(validCounts, 1)
                    if validCounts(row) == 1
                        addStyle(pos_uit, s1, 'cell', [row+1, 1]);
                    elseif validCounts(row) == 2
                        addStyle(pos_uit, s2, 'cell', [row+1, 1]);
                    elseif validCounts(row) == 3
                        addStyle(pos_uit, s3, 'cell', [row+1, 1]);
                    end
                end
            else
                btn_valid.Text = 'Show Data#';
                removeStyle(pos_uit);
            end
        end

        %--------------------------------------------------------------------------
        % button event for btn_r#
        % It consists of three functions.
        % 1. Create a base fig
        % 2. Determine update after determining the created fig
        % 3. Update every data update in the created fig
        %--------------------------------------------------------------------------
        function create_radar_figure(obj, radar_num)
            % create temp_table
            temp_table = obj.distance_table(~all(cellfun('isempty',obj.distance_table(1:end, 2:4)),2), :);
        
            % create fig
            fig_r = uifigure('Name', ['Radar' num2str(radar_num) ' Fig'], 'Tag', ['Radar' num2str(radar_num) ' Fig']);
            fig_r.Position(2) = 200;
            fig_r.Position(3:4) = [720, 1080];
        
            % top graph
            ax_top = uiaxes(fig_r);
            ax_top.Position(2) = 600;
            ax_top.Position(3) = 700;
            ax_top.Position(4) = 400;
            ax_top.Title.String = 'Tag/Distance Graph';
            ax_top.TitleFontWeight = "bold";
            xlabel(ax_top, 'Distance');
            ylabel(ax_top, 'TAG ID');

            % button
            tag_show = uieditfield(fig_r, 'numeric');
            tag_show.Position(1) = 720 - 240;
            tag_show.Position(2) = ax_top.Position(2) - 20;

            btn_his = uibutton(fig_r, 'Tag', 'btn_his_1d');
            btn_his.Position(1) = 720 - 120;
            btn_his.Position(2) = ax_top.Position(2) - 20;
            btn_his.Text = 'Show History';
        
            % bottom table
            radar_table_uit = uitable(fig_r);
            radar_table_uit.Position(3:4) = [680, 500];
            radar_table_uit.ColumnEditable = false;
            radar_table_uit.ColumnName = [];
            radar_table_uit.RowName = [];
            % create Radar Table for bottom table
            temp_radar_table = temp_table(:, [1 1+radar_num 4+radar_num end]);
            radar_table = temp_radar_table(~all(cellfun('isempty', temp_radar_table(1:end, 2)),2),:);
            radar_table_uit.Data = radar_table;
            
            % table title
            table_title = uilabel(fig_r);
            table_title.Text = ['Radar' num2str(radar_num) ' Tags'];
            table_title.FontSize = 20;
            table_title.Position = [radar_table_uit.Position(1), radar_table_uit.Position(2) + radar_table_uit.Position(4) + 10, 200, 30]; % positioning label above the table
            table_title.Position(1) = radar_table_uit.Position(1); % align label with the table
            
            % display mobile separately
            s = uistyle('BackgroundColor', [1 0.6 0.6]);
            for row = 2:size(radar_table, 1)  % get number of rows
                if radar_table{row, end}
                    for col = 1:size(radar_table, 2)  % get number of columns
                        addStyle(radar_table_uit, s, 'cell', [row, col]);
                    end
                end
            end
        
            % top graph
            for index_tag = 2:length(temp_table(:, 1))
                if temp_table{index_tag, radar_num + 1}
                    tag_id = str2double(temp_table{index_tag, 1});
                    tag_distance = temp_table{index_tag, radar_num + 1};
                    stem(ax_top, tag_distance, tag_id, "LineStyle",":","Marker",".", "MarkerSize", 15);
                    hold(ax_top, 'on');
                end
            end 
        
            % top
            grid(ax_top, 'on');
            xlim(ax_top, [0 obj.max_distance]);
            ylim(ax_top, [0 obj.max_tag_num]);
            ax_top.XTick = 0:100:obj.max_distance;

            fig_name = ['fig_r' num2str(radar_num)];
            obj.(fig_name) = fig_r;

            btn_his.ButtonPushedFcn = @(~, ~) show_history_1d(obj, tag_show.Value, radar_num);
        
            drawnow;
        end

        function update_radar_figure(obj) 
            % create temp table
            temp_table = obj.distance_table(~all(cellfun('isempty',obj.distance_table(1:end, 2:end)),2), :);
        
            % for each radar
            for radar_num = 1:3
                % check if the figure for the radar exists
                fig_name = ['fig_r' num2str(radar_num)];
                % disp(findobj(obj.(fig_name)));
                temp_fig = findobj(obj.(fig_name));
                if ~isempty(temp_fig)
                    update_figure_data(obj, temp_fig, temp_table, radar_num);
                end
            end
        end

        function update_figure_data(~, radar_fig, temp_table, radar_num)
            % get the axes and table from the figure
            ax_top = findall(radar_fig, 'Type', 'axes');
            ax_top = ax_top(1);
            radar_table_uit = findall(radar_fig, 'Type', 'uitable');
            radar_table_uit = radar_table_uit(1);
        
            % update the data of the axes
            for index_tag = 2:length(temp_table(:, 1))
                if temp_table{index_tag, radar_num + 1}
                    tag_id = str2double(temp_table{index_tag, 1});
                    tag_distance = temp_table{index_tag, radar_num + 1};
                    stem(ax_top, tag_distance, tag_id, "LineStyle",":","Marker", ".", "MarkerSize", 15);
                    hold(ax_top, 'on');
                end
            end
            hold(ax_top, 'off');
            grid(ax_top, 'on');
        
            % update the data of the table
            temp_table = temp_table(~all(cellfun('isempty', temp_table(1:end, 1+radar_num)),2), :);

            radar_table_uit.Data = temp_table;
        
            % display mobile separately
            s = uistyle('BackgroundColor', [1 0.6 0.6]);
            for row = 2:size(temp_table, 1)  % get number of rows
                if temp_table{row, end}
                    for col = 1:size(temp_table, 2)  % get number of columns
                        addStyle(radar_table_uit, s, 'cell', [row, col]);
                    end
                end
            end
            drawnow;
        end

        %--------------------------------------------------------------------------
        % btn function for show history in both 1d and 3d UI
        %--------------------------------------------------------------------------
        function show_history_1d(obj, tag_show, radar_num)
            if tag_show == 0
                temp_table = obj.buffer_mobile_1d([1, 1+radar_num:3:end], :);
                temp_table = temp_table(~all(cellfun('isempty',temp_table(1:end, 2:end)),2), :);
                err_flag = cellfun('isempty', temp_table(2:end, 2:end));
                fig_flag = 1;
            else
                temp_table = obj.buffer_mobile_1d([1, tag_show*3-2+radar_num], :);
                err_flag = (cellfun('isempty', temp_table(2, 2:end)));
                fig_flag = 2;
            end

            if err_flag
                errordlg('해당 Tag에 대한 데이터 존재하지 않습니다.');
            else
                fig_h = uifigure;

                % for save
                edit_file_name = uieditfield(fig_h);
                btn_save_his = uibutton(fig_h, 'Text', 'Save');
                
                % top graph
                ax_top = uiaxes(fig_h);
                xlabel(ax_top, 'Time');
                ylabel(ax_top, 'Distance');
                
                % bottom table
                radar_table_uit = uitable(fig_h);
                radar_table_uit.ColumnEditable = false;
                radar_table_uit.ColumnName = [];
                radar_table_uit.RowName = [];

                if fig_flag == 1
                    ax_top.Title.String = 'All Tags History';
                    ax_top.TitleFontWeight = "bold";
                    fig_h.Position(2:4) = [200 720 1080];
                    ax_top.Position(2:4) = [600 700 380];
                    radar_table_uit.Position(3:4) = [680, 500];
                    edit_file_name.Position(1:2) = [460 1040];
                    btn_save_his.Position(1:2) = [580 1040];

                    for tag_index = 2:length(temp_table(:, 1))
                        time = [];
                        distance = [];
                        for index_col = 2:length(temp_table(1, :))
                            time = [time temp_table{1, index_col}];
                            if isempty(temp_table{tag_index, index_col})
                                distance = [distance 0];
                                temp_table{tag_index, index_col} = 0;
                            else
                                distance = [distance temp_table{tag_index, index_col}];
                            end
                        end
                        plot(ax_top, time, distance, '-o', 'DisplayName', ['Tag ' temp_table{tag_index, 1}]);
                        hold(ax_top, 'on');
                    end
                    xlim(ax_top, [0 max(time)]);
                    ylim(ax_top, [0 obj.max_distance]);
                    legend(ax_top); % Add legend to the axes
                    grid(ax_top, 'on');
                    hold(ax_top, 'off');
                else
                    ax_top.Title.String = ['Tag ID ' num2str(tag_show) ' Radar' num2str(radar_num) ' ' 'history'];
                    ax_top.TitleFontWeight = "bold";
                    fig_h.Position(2:4) = [200 720 500];
                    ax_top.Position(2:4) = [70 700 400];
                    radar_table_uit.Position(3:4) = [680, 50];
                    edit_file_name.Position(1:2) = [480 460];
                    btn_save_his.Position(1:2) = [600 460];

                    % top graph
                    time = [];
                    distance = [];
                    for index_col = 2:length(temp_table(1, :))
                        time = [time temp_table{1, index_col}];
                        if isempty(temp_table{2, index_col})
                            distance = [distance 0];
                            temp_table{2, index_col} = 0;
                        else
                            distance = [distance temp_table{2, index_col}];
                        end
                    end
                    plot(ax_top, time, distance, '-o');
                    xlim(ax_top, [0 max(time)]);
                    ylim(ax_top, [0 obj.max_distance]);
                    grid(ax_top, 'on');
                end
                radar_table_uit.Data = temp_table; 
                btn_save_his.ButtonPushedFcn = @(~, ~) save_his(obj, edit_file_name.Value, fig_h);
            end
        end

        function show_history_3d(obj, tag_show)
            if tag_show == 0
                temp_table = obj.buffer_mobile_3d(~all(cellfun('isempty',obj.buffer_mobile_3d(1:end, 2:end)),2), :);
                err_flag = cellfun('isempty', temp_table(2:end, 2:end));
                fig_flag = 1;
            else
                temp_table = obj.buffer_mobile_3d([1, tag_show*3-1 tag_show*3 tag_show*3+1], :);
                err_flag = cellfun('isempty', temp_table(2:end, 2:end));
                fig_flag = 2;
            end

            for row = 2:3:length(temp_table(:, 1))
                temp_table{row, 1} = [temp_table{row, 1}];
                temp_table{row+1,1} = [];
                temp_table{row+2,1} = [];
            end

            if err_flag
                errordlg('해당 Tag에 대한 데이터 존재하지 않습니다.');
            else
                fig_h = uifigure;
                fig_h.Position(3:4) = [720 600];
      
                pos_uit = uitable(fig_h);
                pos_uit.Position(2:4) = [50 320 500];
                pos_uit.RowName = [];
                pos_uit.ColumnName = [];
                pos_uit.ColumnEditable = false;
                pos_uit.Data = temp_table;

                ax_3d = uiaxes(fig_h);
                ax_3d.Title.String = '3D UI';
                ax_3d.Position(1:4) = [360 120 360 360];
                ax_3d.XLabel.String = 'X Pos';
                ax_3d.YLabel.String = 'Y Pos';
                ax_3d.ZLabel.String = 'Z Pos';
                ax_3d.XLim = [0 obj.max_distance];
                ax_3d.YLim = [0 obj.max_distance];
                ax_3d.ZLim = [0 obj.max_distance];
                grid(ax_3d, 'on');

                edit_file_name = uieditfield(fig_h);
                btn_save_his = uibutton(fig_h, 'Text', 'Save');
                edit_file_name.Position(1:2) = [460 540];
                btn_save_his.Position(1:2) = [580 540];

                if fig_flag == 1
                    num_id = (length(temp_table(:, 1))-1)/3;
                    for tag_index = 1:num_id
                        X = [];
                        Y = [];
                        Z = [];
                        for col = 2:length(temp_table(1, :))
                            % Check if the cell is empty for each X, Y, and Z
                            if ~isempty(temp_table{(tag_index-1)*3+2, col})
                                X = [X temp_table{(tag_index-1)*3+2, col}];
                            else
                                temp_table{(tag_index-1)*3+2, col} = -1;
                            end
                            if ~isempty(temp_table{(tag_index-1)*3+3, col})
                                Y = [Y temp_table{(tag_index-1)*3+3, col}];
                            else
                                temp_table{(tag_index-1)*3+3, col} = -1;
                            end
                            if ~isempty(temp_table{(tag_index-1)*3+4, col})
                                Z = [Z temp_table{(tag_index-1)*3+4, col}];
                            else
                                temp_table{(tag_index-1)*3+4, col} = -1;
                            end
                        end
                        % Plot and capture the color
                        p = plot3(ax_3d, X, Y, Z, '-*', 'DisplayName', ['Tag ' temp_table{(tag_index-1)*3+1, 1}]);
                        hold(ax_3d, 'on');
                        
                        % Using the captured color for scatter and hiding it from legend
                        scatter3(ax_3d, temp_table{(tag_index-1)*3+2, end}, temp_table{(tag_index-1)*3+3, end}, temp_table{(tag_index-1)*3+4, end}, 'MarkerEdgeColor', p.Color, 'HandleVisibility', 'off');
                    end     
                    legend(ax_3d,'Location', 'best');
                    hold(ax_3d, 'off');
                else
                    % id가 tagshow
                    X = [];
                    Y = [];
                    Z = [];
                    for col = 2:length(temp_table(1, :))
                        % Check if the cell is empty for each X, Y, and Z in this part as well
                        if ~isempty(temp_table{2, col})
                            X = [X temp_table{2, col}];
                        else
                            temp_table{2, col} = -1;
                        end
                        if ~isempty(temp_table{3, col})
                            Y = [Y temp_table{3, col}];
                        else
                            temp_table{3, col} = -1;
                        end
                        if ~isempty(temp_table{4, col})
                            Z = [Z temp_table{4, col}];
                        else
                            temp_table{4, col} = -1;
                        end
                    end
                    plot3(ax_3d, X, Y, Z, '-*');
                    hold(ax_3d, 'on');
                    scatter3(ax_3d, temp_table{2, end}, temp_table{3, end}, temp_table{4, end});
                    hold(ax_3d, 'off');
                end
                btn_save_his.ButtonPushedFcn = @(~, ~) save_his(obj, edit_file_name.Value, fig_h);
            end
        end

        %--------------------------------------------------------------------------
        % btn function save the file for 1d and 3d
        %--------------------------------------------------------------------------
        function save_his(obj, file_name, fig_h)
            dir_path ='D:\2023-summer\matlab_hawkeye\UI_Module\save_data';
            if ~isfolder(dir_path)
                errordlg('유효하지 않은 경로입니다.', '오류');
                return;
            end

            % Check if file already exists
            if isfile(fullfile(dir_path, [file_name, '.fig']))
                choice = questdlg('해당 이름의 파일이 이미 존재합니다. 같은 이름으로 저장하시겠습니까?', ...
                                  '경고', ...
                                  '예', '아니오', '아니오');
                switch choice
                    case '아니오'
                        return; % Exit the function without saving
                end
            end

            % Save the entire uifigure as .fig file
            savefig(fig_h, fullfile(dir_path, [file_name, '.fig']));
        end

    end
end