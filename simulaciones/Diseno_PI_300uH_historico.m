%% DISENO MATEMATICO DEL PI PARA BOOST (METODO DEL DOCENTE)
% Modelo promediado IDEAL, entrada Vin constante (NO es aun panel real).
% No requiere Control System Toolbox. Se usa MATLAB basico y ode45.
% Importante: Las ganancias son EXACTAS PARA LOS POLOS ELEGIDOS,
% NO son ganancias universales ni garantizan funcionamiento con bateria.
clear; clc; close all;

%% 1. DATOS ACTUALES Y PUNTO DE OPERACION
Vin = 19;            % V
Vo = 55;             % V
L = 300e-6;          % H, bobina fabricada
Co = 47e-6;          % F, capacitor de salida
R = 47;              % ohm, carga resistiva
fs = 31370;          % Hz, frecuencia PWM en PSIM
Ppanel = 90;         % W, nominal declarado

q = Vin/Vo;          % q=1-D
D0 = 1-q;
Io = Vo/R;
IL = Io/q;

%% 2. PLANTA Gvd(s)=(a*s+b)/(s^2+c*s+d)
a = -IL/Co;
b = q*Vo/(L*Co);
c = 1/(R*Co);
d = q*q/(L*Co);

fprintf('\n=== PLANTA BOOST EN CCM ===\n');
fprintf('D0=%.8f, Io=%.6f A, IL=%.6f A\n',D0,Io,IL);
fprintf('Gvd(s)=(%.10g*s + %.10g)/(s^2 + %.10g*s + %.10g)\n',a,b,c,d);
fprintf('Polos planta [rad/s]:\n'); disp(roots([1,c,d]));
fprintf('Cero RHP de planta: %.5f rad/s (%.2f Hz)\n',-b/a,(-b/a)/(2*pi));

%% 3. CRITERIOS EXPLICITOS DEL METODO PARAMETRICO
% Polos objetivos = (s+p3)*(s^2+2*zeta*wn*s+wn^2)
% Se adopta como CRITERIO INICIAL wn=sqrt(d), la frecuencia natural
% del par LC de la planta y m=5 (limite inferior sugerido por el docente).
% Se impone p3=m*zeta*wn y se RESUELVE zeta; NO se adivina Kp ni Ki.
wn = sqrt(d);       % rad/s, a partir de la planta
m = 5;              % criterio de separacion de polos del documento

% Igualando s^2 y s^0:
% Kp=((m+2)*zeta*wn-c)/a
% Ki=(m*zeta*wn^3)/b
% Igualando coeficiente de s (y usando wn^2=d), queda:
% 2*m*wn^2*zeta^2 - [(b/a)*(m+2)*wn+(a/b)*m*wn^3]*zeta
% + (b/a)*c = 0
coefZ = [2*m*wn^2, -((b/a)*(m+2)*wn+(a/b)*m*wn^3), (b/a)*c];
raicesZ = roots(coefZ);
validas = real(raicesZ(abs(imag(raicesZ))<1e-9 & real(raicesZ)>0));
if numel(validas)~=1
    error('El criterio escogido no produce una solucion zeta positiva unica.');
end
zeta = validas(1);
p3 = m*zeta*wn;
Kp = ((m+2)*zeta*wn-c)/a;
Ki = (p3*wn^2)/b;
Ti = Kp/Ki;

if ~(Kp>0 && Ki>0 && p3>0)
    error('Solucion no admisible: alguna ganancia o p3 no es positiva.');
end

%% 4. COMPROBACION EXACTA DE LOS 3 COEFICIENTES
% Caracteristico con PI:
% s^3 + (c+a*Kp)*s^2 + (d+b*Kp+a*Ki)*s + b*Ki
polReal = [1,c+a*Kp,d+b*Kp+a*Ki,b*Ki];
polDeseado = conv([1,p3],[1,2*zeta*wn,wn^2]);
errRelativo = max(abs(polReal-polDeseado)./max(1,abs(polDeseado)));
polosLC = roots(polReal);

fprintf('\n=== UBICACION PARAMETRICA EXACTA (criterios m=5, wn=sqrt(d)) ===\n');
fprintf('wn = %.8f rad/s\n',wn);
fprintf('zeta = %.10f\n',zeta);
fprintf('p3 = %.8f rad/s; p3/(zeta*wn)=%.3f\n',p3,p3/(zeta*wn));
fprintf('Kp = %.12f\n',Kp);
fprintf('Ki = %.12f 1/s\n',Ki);
fprintf('Ti = %.12f s (para bloque PI de PSIM)\n',Ti);
fprintf('Error relativo maximo de coeficientes = %.3e\n',errRelativo);
fprintf('Polos reales del lazo cerrado [rad/s]:\n'); disp(polosLC);
fprintf('Estable (todos Re(p)<0): %d\n',all(real(polosLC)<0));

%% 5. RESPUESTA AL ESCALON LOCAL DE 1 V (55 a 56 V)
% Estado de pequena senal x=[delta_iL, delta_Vo, integral_error].
% Este NO es el arranque desde el reposo ni incluye saturacion PWM.
Am = [0,-q/L; q/Co,-1/(R*Co)];
Bm = [Vo/L; -IL/Co];
Cm = [0,1];
Acl = [Am-Bm*Kp*Cm, Bm*Ki; -Cm, 0];
Bcl = [Bm*Kp;1];

t = linspace(0,0.20,10001);
x0 = zeros(3,1);
opciones = odeset('RelTol',1e-8,'AbsTol',1e-10,'MaxStep',2e-5);
[tOut,xOut] = ode45(@(tt,xx) Acl*xx+Bcl*1,t,x0,opciones);
Vsim = Vo+xOut(:,2);
Vref = Vo+1;
peak = max(Vsim);
sobreimpulsoPaso = max(0,(peak-Vref))*100; % % respecto a paso de 1 V
fuera = find(abs(Vsim-Vref)>0.02);           % banda +/-2 % del paso
if isempty(fuera)
    tEst = 0;
elseif fuera(end)<numel(tOut)
    tEst = tOut(fuera(end)+1);
else
    tEst = NaN;
end

fprintf('\n=== PRUEBA LINEAL LOCAL: Vref 55 -> 56 V ===\n');
fprintf('Vmax = %.6f V\n',peak);
fprintf('Sobreimpulso respecto al escalon de 1 V = %.3f %%\n',sobreimpulsoPaso);
if ~isnan(tEst)
    fprintf('Tiempo de establecimiento (+/-2 %% de paso de 1 V) = %.5f s\n',tEst);
else
    fprintf('Sin establecimiento dentro del intervalo simulado.\n');
end

figure('Color','w','Name','Respuesta PI por ubicacion paramétrica');
plot(tOut,Vsim,'b','LineWidth',1.5); hold on;
plot([0,tOut(end)],[Vref,Vref],'k--','LineWidth',1);
plot([0,tOut(end)],[Vref+.02,Vref+.02],'r:');
plot([0,tOut(end)],[Vref-.02,Vref-.02],'r:');
grid on;
xlabel('Tiempo (s)'); ylabel('Vout (V)');
title('Boost lineal: respuesta local a una referencia de 55 a 56 V');
legend('PI calculado','Referencia','Banda +2% del paso','Banda -2% del paso','Location','best');

figure('Color','w','Name','Polos lazo cerrado');
plot(real(polosLC),imag(polosLC),'bx','MarkerSize',10,'LineWidth',2); hold on;
plot([0,0],[-4000,4000],'k--'); grid on;
xlabel('Parte real (rad/s)');ylabel('Parte imaginaria (rad/s)');
title('Polos del controlador calculado');

%% 6. LIMITACIONES
fprintf('\n=== IMPORTANTE ===\n');
fprintf('Ganancias exactas PARA la ubicacion de polos especificada.\n');
fprintf('Falta validar en PSIM el arranque, perturbaciones y saturaciones.\n');
fprintf('No incluye el modelo FV ni la bateria, ni limita la corriente a 5 A.\n');
fprintf('El valor de Ti puede exigir cuidadoso tratamiento del anti-windup y muestreo digital.\n');
fprintf('Dato de panel inconsistente: Vmp*Imp = %.2f W, distinto de %.2f W.\n',19*6.04,Ppanel);
