%% BOOST SOLAR - MODELO Y COMPROBACION DE CONTROL PI
% Archivo: Boost_300uH_47uF_CORREGIDO.m
% Compatible con MATLAB basico; NO requiere Control System Toolbox.
%
% Objetivo: modelo promediado IDEAL de un Boost en CCM, linealizado
% alrededor del punto de operacion de una FUENTE IDEAL de 19 V.
% Este modelo NO simula aun el panel FV, la bateria ni el arranque.
% Una entrada de 1 V en la referencia simula una perturbacion PEQUENA.
%
% Datos acordados: L = 300 uH (fabricada), C2 = 47 uF,
% fs = 31.37 kHz, 19 V -> 55 V, carga resistiva de 47 ohm.
%
% Solo utiliza funciones basicas: eig, roots, ode45, plot, fprintf.

clear;
clc;
close all;

%% 1. Parametros
Vin = 19;              % V
Vout = 55;            % V
L = 300e-6;           % H
Co = 47e-6;           % F (salida)
fs = 31370;           % Hz
R = 47;               % ohm
Ppanel_nom = 90;      % W (dato nominal por confirmar con ficha)

%% 2. Punto de operacion ideal
D0 = 1 - Vin/Vout;
q = 1 - D0;
Iout0 = Vout/R;
IL0 = Iout0/q;
Pout0 = Vout*Iout0;
deltaIL = Vin*D0/(L*fs);
deltaVo = Iout0*D0/(Co*fs); % estimacion ideal sin ESR

fprintf('\n========== DATOS DEL BOOST ==========\n');
fprintf('Vin = %.2f V; Vout = %.2f V; RL = %.2f ohm\n',Vin,Vout,R);
fprintf('L = %.0f uH; C2 = %.0f uF; fs = %.2f kHz\n',L*1e6,Co*1e6,fs/1000);
fprintf('D0 = %.5f (%.2f %%)\n',D0,100*D0);
fprintf('Iout = %.4f A; IL media = %.4f A\n',Iout0,IL0);
fprintf('Potencia en RL = %.2f W\n',Pout0);
fprintf('Rizado inductor: %.3f A pico a pico (%.1f %% de IL de prueba)\n',deltaIL,100*deltaIL/IL0);
fprintf('Rizado salida ideal estimado: %.3f V pico a pico\n',deltaVo);
fprintf('A 90 W y 19 V, rizado relativo ideal de IL = %.1f %%\n',100*deltaIL/(Ppanel_nom/Vin));

%% 3. Modelo promediado de estados (pequena senal)
% Estados: x = [delta_iL; delta_Vout]; entrada delta_D.
% Planta obtenida de las ecuaciones promediadas ideales:
% d(iL)/dt = (Vin-(1-D)*Vout)/L
% d(Vout)/dt = ((1-D)*iL-Vout/R)/Co
A = [0,          -q/L;
     q/Co, -1/(R*Co)];
B = [Vout/L;
     -IL0/Co];
C = [0,1];

% Transferencia Gvd(s) = delta_Vout(s) / delta_D(s)
% Forma: (b1*s + b0)/(s^2 + a1*s + a0)
b1 = -IL0/Co;
b0 = q*Vout/(L*Co);
a1 = 1/(R*Co);
a0 = q*q/(L*Co);
num = [b1,b0];
den = [1,a1,a0];

polosPlanta = roots(den);
cerosPlanta = roots(num);

fprintf('\n========== PLANTA Gvd(s) ==========\n');
fprintf('              %.8g*s + %.8g\n',b1,b0);
fprintf('Gvd(s) = -------------------------------------\n');
fprintf('         s^2 + %.8g*s + %.8g\n',a1,a0);
fprintf('Polos planta [rad/s]:\n');
disp(polosPlanta);
fprintf('Cero planta [rad/s]:\n');
disp(cerosPlanta);
if any(real(cerosPlanta)>0)
    fprintf('ATENCION: CERO EN SEMIPLANO DERECHO; restringe rapidez de control.\n');
end

%% 4. Dos controladores PI de comprobacion
% PSIM PI: Gain = Kp; Time Constant = Ti; Ki = Kp/Ti.
% Estos valores son de PRUEBA, no el diseno definitivo.
Kp = [0.005,  0.0015];
Ti = [0.005,  0.010];
Ki = Kp./Ti;

% El controlador usa error = referencia - salida:
% delta_D = Kp*(delta_ref - delta_Vout) + Ki*z
% dz/dt = delta_ref - delta_Vout
% Con x_aug = [delta_iL; delta_Vout; z]:
% dx_aug/dt = Acl*x_aug + Bcl*delta_ref
Acl = cell(1,2);
Bcl = cell(1,2);
polosLazo = cell(1,2);

for k = 1:2
    Acl{k} = [A - (B*Kp(k))*C, B*Ki(k);
              -C,              0];
    Bcl{k} = [B*Kp(k);1];
    polosLazo{k} = eig(Acl{k});

    % Comprobacion independiente por polinomio caracteristico:
    % s*den(s) + (Kp*s+Ki)*num(s)
    polinomio = [den,0] + [0,conv([Kp(k),Ki(k)],num)];
    polosPorPolinomio = roots(polinomio);

    fprintf('\n========== CONTROLADOR PI %d ==========\n',k);
    fprintf('Kp = %.6f, Ti = %.6f s, Ki = %.6f\n',Kp(k),Ti(k),Ki(k));
    fprintf('Polos del lazo cerrado [rad/s]:\n');
    disp(polosLazo{k});
    fprintf('Polos calculados por el polinomio caracteristico:\n');
    disp(polosPorPolinomio);

    if all(real(polosLazo{k}) < -1e-8)
        fprintf('ESTABLE en el modelo lineal: SI\n');
    else
        fprintf('ESTABLE en el modelo lineal: NO\n');
    end
end

%% 5. Respuesta lineal a un cambio PEQUENO de referencia
% Se parte de Vout = 55 V en equilibrio, y a t = 0
% se solicita aumentar 1 V la referencia: 55 -> 56 V.
% Esta es una respuesta LOCAL; no es simulacion de arranque.
deltaRef = 1;  % V
Tfinal = 0.20;
tspan = linspace(0,Tfinal,2001);
x0 = zeros(3,1);
opts = odeset('RelTol',1e-7,'AbsTol',1e-9,'MaxStep',1e-4);

[t1,x1] = ode45(@(t,x) Acl{1}*x + Bcl{1}*deltaRef, tspan, x0, opts);
[t2,x2] = ode45(@(t,x) Acl{2}*x + Bcl{2}*deltaRef, tspan, x0, opts);

V1 = Vout + x1(:,2);
V2 = Vout + x2(:,2);

figure('Color','w','Name','Respuesta del Boost con PI');
plot(t1,V1,'b-','LineWidth',1.1);
hold on;
plot(t2,V2,'r-','LineWidth',1.5);
plot([0,Tfinal],[Vout+deltaRef,Vout+deltaRef],'k--','LineWidth',1.1);
grid on;
xlabel('Tiempo (s)');
ylabel('Voltaje de salida (V)');
title('Modelo lineal: pequeno cambio de referencia 55 a 56 V');
legend('PI anterior: Kp=0.005, Ti=0.005 s', ...
       'PI de prueba: Kp=0.0015, Ti=0.010 s', ...
       'Referencia = 56 V','Location','best');

%% 6. Ubicacion de polos y cero de la planta
figure('Color','w','Name','Polos y cero del Boost');
plot(real(polosPlanta),imag(polosPlanta),'bx','MarkerSize',10,'LineWidth',2);
hold on;
plot(real(cerosPlanta),imag(cerosPlanta),'ro','MarkerSize',9,'LineWidth',2);
plot([0,0],[-4500,4500],'k--');
grid on;
xlabel('Parte real (rad/s)');
ylabel('Parte imaginaria (rad/s)');
title('Polos (X) y cero (O) de Gvd(s)');
legend('Polos','Cero','Eje imaginario','Location','best');

%% 7. Avisos de alcance
fprintf('\n========== ADVERTENCIAS ==========\n');
fprintf('Este calculo NO requiere Control System Toolbox.\n');
fprintf('Es modelo lineal promediado, ideal, sin saturacion PWM.\n');
fprintf('NO demuestra arranque suave ni estabilidad con panel real.\n');
fprintf('Los 5 A son un LIMITE de carga, NO una consigna.\n');
fprintf('Datos del panel a confirmar: 19*6.04 = %.2f W, distinto de 90 W.\n',19*6.04);
fprintf('El PI definitivo se ajustara con el metodo del docente y PSIM.\n');
fprintf('FIN DEL SCRIPT.\n');
