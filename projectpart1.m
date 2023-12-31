function projectpart1()
    clear all;
    tic
        
% Tên node và ID của node
    A=1;
    B=2;
    % mảng động elist[n 6] với n là số packets đợi trong hàng đợi giữa node A và B
    % / 1 hàng trong mảng elist tương đương một packets
    elist=[];
    
    % khởi tạo giá trị ban đầu
    SRC=1;      % Id nút nguồn / bắt đầu từ nút A
    GENTIME=2;  % thời-gian packet được tạo ở nút nguồn
    TXTIME=3;   % Thời-gian bắt đầu truyền-gói
    RXTIME=4;   % Thời-gian-mà gói được nhận tại điểm đến
    CURTIME=5; % thời gian chương trình đã chạy
    COLLISIONS=6; % số va chạm trước khi truyền thành công    

    % Reference:
    % http://en.wikipedia.org/wiki/Discrete_event_simulation#Clock 
    % Clock:
    % Sử dụng biến CLOCK thể hiện thời gian chạy mô phỏng.
    CLOCK=0;
 
    TOTALSIM=30*10^3; % Thời gian thực hiện chương trình/mô phỏng
    lambda = 0.5; %phân phối poisson
    frameslot = 50; % frame slot time (usec) thời gian truyền 1 framee 
    td = 80;% trễ lan truyền on BUS (usec)
    pd = 10; % trễ phục vụ gói on BUS
    tdelay = td + pd; % tổng trễ
    tbackoff = frameslot; % time slot (usec) dùng cho giải thuật backoff
    maxbackoff = 3; % thời gian backoff tối đa là 2^3 frame slot.
	
    % lưu thời gian chạy mô phỏng mỗi khi có packet được tạo ở cả node A và B
    GENTIMECURSOR = [0 0]; 
    % hàm tạo gói.   
    
    % khởi tạo 2 paket ban đầu cho 2 node A, B sử dụng hàm create packet ở trên
    createpacket(A); 
    createpacket(B);

% kiểm tra xem có packet không
    if size(elist, 1) == 0
        disp('No packets to simulate');
        return;
    end

    % khởi tạo mảng để thu thập số liệu thống kê
    SIMRESULT = [];
while(1)
        
        %dùng hàm updateclock ở project 1
        updateclock();     
        % lấy packet ở hàng đầu tiên trong elist để truyền.
        src = elist(1,SRC);
		dst = mod(src,2)+1;
        timediff = elist(2,CURTIME) - elist(1,CURTIME);
        % chênh lệch thời gian truyền 
        
		if timediff > pd
			%timediff > pd không có va chạm xảy ra
            if elist(1,TXTIME) == 0
                elist(1,TXTIME) = elist(1,CURTIME);
            end
            
            elist(1,RXTIME) = elist(1,CURTIME) + tdelay;

            updatesimlist();
			
            createpacket(src);
			
			
            delaypkts(tdelay);
        else
            
            if elist(1,TXTIME)==0
                elist(1,TXTIME)=elist(1,CURTIME);
            end
            if elist(2,TXTIME)==0
                elist(2,TXTIME)=elist(2,CURTIME);
            end
            elist(1,COLLISIONS)=elist(1,COLLISIONS)+1;
            elist(2,COLLISIONS)=elist(2,COLLISIONS)+1;
            
            if (elist(1,COLLISIONS)<maxbackoff)
                bk(src)=(randi(2^(elist(1,COLLISIONS)),1,1)-1)*tbackoff;
            else
                bk(src)=(randi(2^(maxbackoff),1,1)-1)*tbackoff;
            end
            if (elist(2,COLLISIONS)<maxbackoff)
                bk(dst)=(randi(2^(elist(2,COLLISIONS)),1,1)-1)*tbackoff;
            else
                bk(dst)=(randi(2^(maxbackoff),1,1)-1)*tbackoff;
            end
            delaynodepkts(src,pd+timediff+bk(src));
            delaynodepkts(dst,pd-timediff+bk(dst));
        end
		
        if min(GENTIMECURSOR) > TOTALSIM
            disp('Completed!');
            calcstat();
            break;
        end
    end
        %lặp lại cho đến khi GENTIMECURSOR < TOTALSIM
%khi kết thúc mô phỏng hàm caclstat() thực hiện tính các thông số cần thiết từ mảng SIMRESULT (được tạo trong quá trình mô phỏng) để tính các thông số liên quan.

    
       
	   function calcstat()
        AtoB=SIMRESULT(SIMRESULT(:,SRC)==A,:);
        BtoA=SIMRESULT(SIMRESULT(:,SRC)==B,:);
        
        % tổng gói tin được gửi 
        AtoBnum=length(AtoB);
        BtoAnum=length(BtoA);
        
        % Queue delay
        queuedelaya=AtoB(:,RXTIME)-AtoB(:,GENTIME);
        queuedelayb=BtoA(:,RXTIME)-BtoA(:,GENTIME);
        queuedelaya=queuedelaya-tdelay;
        queuedelayb=queuedelayb-tdelay;
        
        figure;
        subplot(3,2,1)
        plot(1:size(queuedelaya,1),queuedelaya(1:end))
        axis([0 AtoBnum 0 max(queuedelaya)])
        xlabel('Packet sequence #');
        ylabel('Delay in \mu sec');
        title('Queue delay at node A');
        
        subplot(3,2,2)
        plot(1:size(queuedelayb,1),queuedelayb(1:end))
        axis([0 BtoAnum 0 max(queuedelayb)])
        xlabel('Packet sequence #');
        ylabel('Delay in \mu sec');
        title('Queue delay at node B');   
        
        % Access delay
        accessdelaya=AtoB(:,RXTIME)-AtoB(:,TXTIME);
        accessdelayb=BtoA(:,RXTIME)-BtoA(:,TXTIME);
        
        subplot(3,2,3)
        plot(1:size(accessdelaya,1),accessdelaya(1:end))
        axis([0 AtoBnum 0 max(accessdelaya)])
        xlabel('Packet sequence #');
        ylabel('Delay in \mu sec');
        title('Access delay at node A');
        
        subplot(3,2,4)
        plot(1:size(accessdelayb,1),accessdelayb(1:end))
        axis([0 BtoAnum 0 max(accessdelayb)])
        xlabel('Packet sequence #');
        ylabel('Delay in \mu sec');
        title('Access delay at node B');
        
        % Frame interval
        subplot(3,2,5)
        frameintba=BtoA(2:end,GENTIME)-BtoA(1:end-1,GENTIME);
        plot(1:BtoAnum-1,frameintba/1000)
        axis([0 BtoAnum 0 max(frameintba)/1000])
        xlabel('Packet sequence #');
        ylabel('Frame interval in msec');
        title('Frame intervals at node B');
        
        subplot(3,2,6)
        frameintab=AtoB(2:end,GENTIME)-AtoB(1:end-1,GENTIME);
        plot(1:AtoBnum-1,frameintab/1000)
        axis([0 AtoBnum 0 max(frameintab)/1000])
        xlabel('Packet sequence #');
        ylabel('Frame interval in msec');
        title('Frame intervals at node A');
        
        
        
        figure;
        subplot(2,1,1)
        hist(frameintab,60);
        xlabel('frame intervals in \mu sec');
        ylabel('# of frames');
        subplot(2,1,2)
        hist(frameintba,60);
        xlabel('frame intervals in \mu sec');
        ylabel('# of frames');
        
       
        meanendtoenda=mean(AtoB(:,RXTIME)-AtoB(:,GENTIME));
        
        meanendtoendb=mean(BtoA(:,RXTIME)-BtoA(:,GENTIME));
        
        
        Avgtha=((1000*8)/meanendtoenda)*10^6;  % bits/sec
        Avgthb=((1000*8)/meanendtoendb)*10^6;  % bits/sec
        avgth2=mean(8000.*(AtoB(:,RXTIME)-AtoB(:,GENTIME)).^(-1));
        
        fprintf('Total packets sent from node A=%d\n',AtoBnum);
        fprintf('Total packets sent from node B=%d\n',BtoAnum);
        fprintf('Average frame interval at node A=%d\n',mean(frameintab));
        fprintf('Average frame interval at node B=%d\n',mean(frameintba));
        fprintf('Average access delay at node A=%d\n',mean(accessdelaya));
        fprintf('Average access delay at node B=%d\n',mean(accessdelayb));
        fprintf('Average queue delay at node A=%d\n',mean(queuedelaya));
        fprintf('Average queue delay at node B=%d\n',mean(queuedelayb));
        fprintf('Average end to end throughput from A to B=%d\n',Avgtha);
        fprintf('Average end to end throughput from B to A=%d\n',Avgthb);
        fprintf('Simulation end time=%d\n',CLOCK);
       end

   %Hàm tạo delay
    function delaypkts(delay)
        CLOCK=CLOCK+delay;
         % có thể xuất hiện tình huống packet mới từ nguồn được truyền đi khi còn packet cũ trên      
       % đường truyền, lúc này packet mới phải đợi cho đến khi packet cũ tới đích.

      % trường hợp này được mô tả trong chương trình như sự kiện CURTIME < CLOCK(lúc 
      % này CLOCK đang đóng vai trò như RXTIME.) 

        list=find(((elist(:,CURTIME)-CLOCK) < 0));
        % Lúc này, đặt lại CURTIME của tất cả các hàng (packet phải đợi) trong elist về CLOCK 
        elist(list,CURTIME)=CLOCK;
    end
%hàm update thời gian
  function updateclock()
    % hàm SORTROWS(elist,CURTIME) sắp xếp lại các gói theo thứ tự tăng dần của  
    %CURTIME / phòng trường hợp Curtime có giá trị không mong muốn trong khi mô phỏng.         
    elist=sortrows(elist,CURTIME);
     % đặt lại CLOCK theo CURTIME của packet đầu tiên(packet đầu tiên đến kênh)
        CLOCK=elist(1,CURTIME);
  end
   % hàm tạo gói. 
    function pkt = createpacket(nodeid)
        % Tính thời gian đến.
        interarvtime = round(frameslot*exprnd(1/lambda,1,1));
        % dùng hàm tạo ngẫu nhiên, kiểu mảng, làm tròn bỏ phần thập phân
        
        % thời gian sinh packets tại nodeid.
        GENTIMECURSOR(nodeid) = GENTIMECURSOR(nodeid)+interarvtime;
        
        % tạo packet tại nodeid
        % [SRC= nodeid GENTIME=birthtime TXTIME=0, RXTIME=0 CURTIME=birthtime    
        % COLLISIONS=0]
        pkt = [nodeid GENTIMECURSOR(nodeid) 0 0 GENTIMECURSOR(nodeid) 0];
        
        % thêm vào ma trận packet: elist/ dùng lệnh X=[X; x]
        elist = [elist; pkt];
    end
%hàm tìm giá trị CURTIME
	function t=getcurtime(node)
		idx=find(elist(:,SRC)==node,1,'first');
        %idx là vị trí đầu tiên trong elist mà CURTIME < DELAYTIME
        t=elist(idx,CURTIME);
    end
	% tính thời gian delay trong trường hợp có va chạm
    function delaynodepkts(node,delay)
        DELAYTIME = getcurtime(node)+delay;
        % tính delay time
        list = find(elist(:,CURTIME) - DELAYTIME < 0 & elist(:,SRC) == node); 
% đặt lại CURTIME của tất cả các packets trong elist (hàng đợi) thành DELAYTIME.
        elist(list,CURTIME) = DELAYTIME;
    end
   function updatesimlist()
        SIMRESULT=[SIMRESULT; elist(1,1:end)];
        elist(1,:)=[];
   end
disp(toc);

end

