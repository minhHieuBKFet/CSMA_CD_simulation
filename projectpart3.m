function projectdemo3()
    clear all;
    tic
    
    % NODE Id's
     A = 1; B = 2; C = 3; D = 4;
    nodes = [A, B, C, D];
    % mảng elist(n,7),  1 hàng tương đương 1 packet
    % [SRC DEST GENTIME TXTIME RXTIME CURTIME COLLISIONS]

    elist1 = [];    % tượng trưng cho bus 1
    elist2 = [];    % tượng trưng cho bus 2
    
   % Columns in the event list
    SRC = 1;      % id nút nguồn
    DEST = 2;     % Id nút đích
    GENTIME = 3;  % thời-gian packet được tạo ở nút nguồn
    TXTIME = 4;   % Thời-gian bắt đầu truyền-gói
    RXTIME = 5;   % Thời-gian-mà gói được nhận tại điểm đến    
    CURTIME = 6;  % thời gian chương trình đã chạy
    COLLISIONS = 7; % số va chạm trước khi truyền thành công    
    
    CLOCK = 0;
 
    TOTALSIM = 30*10^3; % Thời gian thực hiện chương trình/mô phỏng
    lambda = .5;% phân phối poisson
    frameslot = 500; % frame slot time (usec) thời gian truyền 1 framee 
    td = 80;% trễ lan truyền on BUS (usec)
    pd = 10; % trễ phục vụ gói on BUS
    tdelay = td + pd; % tổng trễ
    tbackoff = frameslot; % time slot (usec) dùng cho giải thuật backoff
    maxbackoff = 3; % thời gian backoff tối đa là 2^3 frame slot.	

    % mảng GENTIMECURSOR khi packet được tạo ở các nút A, B, C, D 
    GENTIMECURSOR = [0 0 0 0];

        
    % khởi tạo packet cho tất cả node
    [x, y] = size(nodes);
     for n = 1:y
         createpacket(n);
     end

    
    if(size(elist1, 1) == 0 && size(elist2, 1) == 0)
        disp('No packets to simulate');
        return;
    end
    SIMRESULT = [];
        
    while(1)  
        % Update clock.
        updateclock(); 
        
        % lấy node nguồn 1 cách ngẫu nhiên từ hàng 1 của elist1 và elist2
        l1 = elist1(1,SRC); l2 = elist2(1,SRC);
        l = horzcat(l1, l2);
        randomindex = randi(length(l));
        src = l(randomindex);
		
        % khởi tạo một node đích ngẫu nhiên
        destnodes = nodes;
        destnodes(src) = [];
        randomindex = randi(length(destnodes));
        dst = destnodes(randomindex);
        
        % nếu source note ở bus 1, cập nhật elist1; ngược lại,cập nhật elist 2
        if src == 1 || src == 2
            bus1 = true; bus2 = false;      % bus1 là bus truyền đi
            elist1(1,DEST) = dst;
        else
            bus1 = false; bus2 = true;      % bus2 là bus truyền đi
            elist2(1,DEST) = dst;
        end
        
        % thiết lập lộ trình (route) cho packet nếu nó có đích là bus còn lại
        if ((src == 1 || src == 2) && (dst == 3 || dst == 4)) || ((src == 3 || src == 4) && (dst == 1 || dst == 2))
            routing = true;
            routingpackets(src, dst);
        else
            routing = false;
        end
        
        timediff1 = elist1(2,CURTIME) - elist1(1,CURTIME);
        timediff2 = elist2(2,CURTIME) - elist2(1,CURTIME);
        
		if(timediff1 > pd && timediff2 > pd)
            if ~routing
                tdelay = 90;        % đặt lại transmission delay khi không routing
            end
            
                  % paket được truyền từ elist1 , cập nhật thời gian truyền (transmission) và nhận (receive) của packet từ elist
            if bus1
                if elist1(1,TXTIME) == 0
                    elist1(1,TXTIME) = elist1(1,CURTIME);
                end
                % Set the rx time.
                elist1(1,RXTIME) = elist1(1,CURTIME) + tdelay;
            end
            
            % paket được truyền từ elist2 , cập nhật thời gian truyền (transmission) và nhận (receive) của packet từ elist
            if bus2
                if elist2(1,TXTIME) == 0
                    elist2(1,TXTIME) = elist2(1,CURTIME);
                end
                % rx time.
                elist2(1,RXTIME) = elist2(1,CURTIME) + tdelay;
            end

            updatesimlist();% cập nhật các thông số cho mảng kết quả
			
            createpacket(src);
			
			% add tdelay to CLOCK. Check delaypkts() for more details.
            delaypkts(tdelay);
       else
            backoffoncollision();
       end
		
        if min(GENTIMECURSOR) > TOTALSIM
            disp('Completed!');
            calcstat();
            break;
        end
    end
      
	   function calcstat()
        % nodename = ['A', 'B', 'C', 'D']; 
        figure(1);
        figure(2);
        plotcount = 0;
        f = [];
        for i = 1:4		% nguồn
			source = nodes(i);
            var3 = 0;
            queuedelay = 0;
            accessdelay = 0;
			for j = 1:4		% đích
				if j ~= i
                    plotcount = plotcount + 1;
					destination = nodes(j);                    
					var1 = SIMRESULT(SIMRESULT(:,SRC) == source,:);
                    var1 = var1(var1(:,DEST) == destination,:);
                    
                    % số gói tin gửi từ node i đến node j
                    var2 = length(var1);
                    
                    % queuing delay từ node i đến node j
                    var3 = var1(:, RXTIME) - var1(:, GENTIME);
                    figure(1);
                    plottitle = strcat('Queue delay from node ', num2str(i), ' to ', num2str(j));
                    queuedelay = sum(var3);     
                    subplot(4,3, plotcount);
                    plot(1:length(var3),var3);
                    xlabel('Packet sequence #');
                    ylabel('Delay in \mu sec');
                    title(plottitle);
                    
                    % Access delay
                    var4 = var1(:, RXTIME) - var1(:, TXTIME);
                    figure(2);
                    accessdelay = sum(var4);
                    plottitle = strcat('Access delay from node ', num2str(i), ' to ', num2str(j));
                    subplot(4,3, plotcount);
                    plot(1:length(var4),var4);
                    xlabel('Packet sequence #');
                    ylabel('Delay in \mu sec');
                    title(plottitle);
                    
                    var5 = var1(:, COLLISIONS);
                    noofcollisions = sum(var5);
                    meanendtoend = mean(var3);                    
                    % Avgtha=((1000*8)/meanendtoenda)*10^6;  % bits/sec
                    avgthroughput = ((1000*8)/meanendtoend)*10^6;  % bits/sec
                    f = [f; i j avgthroughput var2 noofcollisions];
               end
            end
            % tổng queuing delay tại node A, B, C và D
            queuedelay = queuedelay - 3*tdelay;
        end
        disp(array2table(f, 'VariableNames',{'Source','Destination','Throughput', 'NoOfPacketsSent', 'NoOfCollisions'}));
    end
	

    function delaypkts(delay)
        CLOCK = CLOCK + delay;
        % có thể xuất hiện tình huống packet mới từ nguồn được truyền đi khi còn packet cũ trên      
       % đường truyền, lúc này packet mới phải đợi cho đến khi packet cũ tới đích.

        
        % trường hợp này được mô tả trong chương trình như sự kiện CURTIME < CLOCK(lúc 
      % này CLOCK đang đóng vai trò như RXTIME.)  
        list1 = find(((elist1(:,CURTIME)-CLOCK) < 0));
        list2 = find(((elist2(:,CURTIME)-CLOCK) < 0));
        % đặt lại CURTIME của tất cả các hàng (packet phải đợi) trong elist về CLOCK 
        elist1(list1,CURTIME) = CLOCK;
        elist2(list2,CURTIME) = CLOCK;
    end
   
    function updateclock()
        % hàm SORTROWS(elist,CURTIME) sắp xếp lại các gói theo thứ tự tăng dần của  
        %CURTIME 
        elist1 = sortrows(elist1, CURTIME);
        elist2 = sortrows(elist2, CURTIME);
        
        % đặt lại CLOCK theo CURTIME của packet đầu tiên(packet đầu tiên đến kênh)
        CLOCK = min(elist1(1,CURTIME), elist2(1,CURTIME));
    end
   % hàm khởi tạo createpacket
     function pkt = createpacket(nodeid)
        %  inter-arrival time.
        interarvtime = round(frameslot*exprnd(1/lambda,1,1));
        
        %  the birth time.
        GENTIMECURSOR(nodeid) = GENTIMECURSOR(nodeid) + interarvtime;
        
        % tạo gói.  Unknown fields are set to 0.
        % [SRC = nodeid DEST = 0 GENTIME = birthtime TXTIME = 0, RXTIME = 0
        % CURTIME = birthtime COLLISIONS = 0]
        pkt = [nodeid 0 GENTIMECURSOR(nodeid) 0 0 GENTIMECURSOR(nodeid) 0];
        
        
        if(nodeid == 1 || nodeid == 2) % node 1,2 ở LAN1
            elist1 = [elist1; pkt];
        else
            elist2 = [elist2; pkt]; % node 3,4 ở LAN2
        end
    end


	function t = getcurtime(node, elist)
		idx = find(elist(:,SRC) == node, 1, 'first');
        t = elist(idx, CURTIME);
    end
	
    function delaynodepkts(node, delay)
        if bus1
            DELAYTIME = getcurtime(node, elist1) + delay;
            list = find(elist1(:,CURTIME)-DELAYTIME < 0 & elist1(:,SRC)==node); 
            elist1(list,CURTIME) = DELAYTIME;
        else
            DELAYTIME = getcurtime(node, elist2) + delay;
            list = find(elist2(:,CURTIME)-DELAYTIME < 0 & elist2(:,SRC)==node); 
            elist2(list,CURTIME) = DELAYTIME;
        end
            
	end
   
    % đưa hàng đầu tiên của elist vào SIMRESULT ( đồng thời xóa packet từ elist)
    function updatesimlist()
   
        if bus1 
            SIMRESULT = [SIMRESULT; elist1(1,1:end)];          
            elist1(1,:)=[];
        end
        
        if bus2
            SIMRESULT = [SIMRESULT; elist2(1,1:end)];
            elist2(1,:)=[];
        end
        
    end
% Hàm tạo lộ trình 
    function routingpackets(src, dst)
        
       % giả định giữa 2 LAN1 và LAN2 (bus1 và bus2) có 4 nút router R1->4
        % networknodes = [R1, R2, R3, R4];
        adj = [0 0 1 1; 0 0 1 1; 1 1 0 0; 1 1 0 0];               % khởi tạo các đường có thể đi giữa các router R (1,2<->3,4)
        c1 = randi([1,10],1); c2 = randi([1,10],1);               % phân bố uniform [1, 10] tính trọng số của đường truyền 
        c3 = randi([1,10],1); c4 = randi([1,10],1);               % một c tương ứng 1 đường truyền
        % c1 = w(r1, r3); c2 = w(r1, r4); c3 = w(r2, r3); c4 = w(r2, r4)
        edgeweights = [0 0 c1 c2; 0 0 c3 c4; c1 c2 0 0; c3 c4 0 0]; %mảng các trọng số tương ứng
        
        % sử dụng thuật toán dijkstra cho tìm đường đi ngắn nhất.
        [costs, paths] = dijkstra(adj, edgeweights);  % thiết lập mảng đường đi – trọng số
        pathlength = cellfun('length', paths);            % số lần “hop” trên đường đi của packet  
              
        if((src == 1 || src == 2) && (dst == 3 || dst == 4))    % nguồn ở bus1 và đích ở bus2

            rcosts = costs(1:2, 3:4);
            [~, index] = min(rcosts(:));                        % lấy giá trị trọng số nhỏ nhất tính từ thuật toán dijkstra
             [srouter, drouter] = ind2sub(size(rcosts), index);  % lấy node source và router R tương ứng với trọng số ở trên
            drouter = drouter + 2;                              % lấy router đích từ mảng trọng số ban đầu
            rtdelay = 8;                                        % transmission delay giữa các routers (1Gbps)
            % tính lại delay (bổ sung thêm delay khi packet đi qua các router
            tdelay = tdelay + ((pathlength(srouter, drouter) - 1) * (rtdelay + pd)) + (td + pd);         
        end
        
        if((src == 3 || src == 4) && (dst == 1 || dst == 2))    % source ở bus2, đích ở bus1
            rcosts = costs(3:4, 1:2);
            [~, index] = min(rcosts(:));                        % lấy giá trị trọng số nhỏ nhất tính từ thuật toán dijkstra
            [srouter, drouter] = ind2sub(size(rcosts), index);  % tương tự trên
            srouter = srouter + 2; % ?
            tdelay = tdelay + ((pathlength(srouter, drouter)) * (td + pd));         
         
        end
    end

    function backoffoncollision
        % Cập nhật lại các biến COLLISIONS trong elist 1
        if(timediff1 <= pd)
            if elist1(1,TXTIME) == 0
                elist1(1,TXTIME) = elist1(1,CURTIME);
            end
            if elist1(2,TXTIME) == 0
                elist1(2,TXTIME) = elist1(2,CURTIME);
            end
            elist1(1, COLLISIONS) = elist1(1, COLLISIONS) + 1;
            elist1(2, COLLISIONS) = elist1(2, COLLISIONS) + 1;

            % tính thời gian backoff  theo điều kiện backoff tối đa
            if (elist1(1, COLLISIONS) < maxbackoff)
                bk(src)=(randi(2^(elist1(1,COLLISIONS)),1,1)-1)*tbackoff;
            else
                bk(src)=(randi(2^(maxbackoff),1,1)-1)*tbackoff;
            end
            if((src == 1 && dst == 2) || (dst == 1 && src == 2))
                if (elist1(2,COLLISIONS)<maxbackoff)
                    bk(dst)=(randi(2^(elist1(2,COLLISIONS)),1,1)-1)*tbackoff;
                else
                    bk(dst)=(randi(2^(maxbackoff),1,1)-1)*tbackoff;
                end

                % tính lại delay tại nút đích trong trường hợp 2 nút đích – nguồn cùng bus
                delaynodepkts(dst, pd - timediff1 + bk(dst));
            end
                % tính lại delay tại nút nguồn
            delaynodepkts(src, pd + timediff1 + bk(src));
        end
        % tương tự với elist 2
      if(timediff2 <= pd) 
            % Cập nhật lại các biến COLLISIONS trong elist2
            if elist2(1,TXTIME) == 0
                elist2(1,TXTIME) = elist2(1,CURTIME);
            end
            if elist2(2,TXTIME) == 0
                elist2(2,TXTIME) = elist2(2,CURTIME);
            end

            elist2(1, COLLISIONS) = elist2(1, COLLISIONS) + 1;
            elist2(2, COLLISIONS) = elist2(2, COLLISIONS) + 1;

           % tính thời gian backoff  theo điều kiện backoff tối đa
            if (elist2(1, COLLISIONS) < maxbackoff)
                bk(src)=(randi(2^(elist2(1,COLLISIONS)),1,1)-1)*tbackoff;
            else
                bk(src)=(randi(2^(maxbackoff),1,1)-1)*tbackoff;
            end
            if((src == 3 && dst == 4) || (dst == 3 && src == 4))
                if (elist2(2,COLLISIONS)<maxbackoff)
                    bk(dst)=(randi(2^(elist2(2,COLLISIONS)),1,1)-1)*tbackoff;
                else
                    bk(dst)=(randi(2^(maxbackoff),1,1)-1)*tbackoff;
                end
                % tính lại delay tại nút đích trong trường hợp 2 nút đích – nguồn cùng bus
                delaynodepkts(dst, pd - timediff2 + bk(dst));
            end
                % tính lại delay tại nút nguồn
            delaynodepkts(src, pd + timediff2 + bk(src));

        end
    end
    
disp(toc);

end
