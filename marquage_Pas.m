% marquage_Pas(chemin, montrerGraphique, marquagePhaseMarche) : marquage automatique des foot off, foot strike et des
% aller/demi-tour/retour.
%
% Entrée: des fichiers C3D dans un dossier spécifié, sans trous sur les
% mires de calcul (RHEE, LHEE et mire de référence pour le demi-tour).
% Sortie: les mêmes fichiers C3D mis à jour dans ce dossier
%
% montrerGraphique = 1 (par défaut, paramètre facultatif), un graphique est montré pour chaque
% fichier C3D avec les évènements qui sont affichés. Il faut appuyer sur
% une touche pour passer au C3D suivant. Fixer à
% 0 pour ne pas l'activer.
%
% marquagePhaseMarche = 1 (par défaut, paramètre facultatif), marquage des aller, demi-tour,
% retour. Fixer à 0 pour ne pas l'activer. Prendre une mire latérale qui se
% trouve à l'extrémité du demi-tour. Exemple: dans MAGIC: LELB car demi
% tour de la gauche vers la droite.

function marquage_Pas(chemin, montrerGraphique, marquagePhaseMarche)
    cd(chemin);
    listeFichiersC3D    = dir('*.c3d');
    nombreFichiersC3D   = length(listeFichiersC3D);
    
    if nargin < 3 || isempty(montrerGraphique)
        montrerGraphique = 1;
    end
    
    if nargin < 3 || isempty(marquagePhaseMarche)
        marquagePhaseMarche = 1;
    end

    for i = 1:nombreFichiersC3D
        acq              = btkReadAcquisition(listeFichiersC3D(i).name);
        marqueurs        = btkGetMarkers(acq);
        marqueurDemiTour = marqueurs.RTRO(:,1); %A ajuster en fonction du type de demi-tour et des mires disponibles.
        frequence        = btkGetPointFrequency(acq); % fréquence d'acquisition des caméras
        btkClearEvents(acq);

        [pks, locs] = findpeaks(marqueurs.LHEE(:,3), "MinPeakProminence", 50); %On enlève par défaut les 50 dernières frames.
        structure.Left_Foot_Off = locs'/frequence;

        [pks, locs] = findpeaks(marqueurs.RHEE(:,3), "MinPeakProminence", 50);
        structure.Right_Foot_Off = locs'/frequence;

        [pks, locs] = findpeaks(marqueurs.LHEE(:,3)*-1, "MinPeakProminence", 10);
        structure.Left_Foot_Strike = locs'/frequence;

        [pks, locs] = findpeaks(marqueurs.RHEE(:,3)*-1, "MinPeakProminence", 10);
        structure.Right_Foot_Strike = locs'/frequence;

        %Création du graphique mettant en évidence les évènements détectés,
        %uniquement si montrerGraphique est fixé à true.
        if montrerGraphique == 1
            figure('Name', listeFichiersC3D(i).name,'NumberTitle','off')
            subplot(221)
            findpeaks(marqueurs.LHEE(:,3), "MinPeakProminence", 50), title('Foot Off Gauche')
            subplot(222)
            findpeaks(marqueurs.RHEE(:,3), "MinPeakProminence", 50), title('Foot Off Droit')
            subplot(223)
            findpeaks(marqueurs.LHEE(:,3)*-1, "MinPeakProminence", 10), title('Foot Strike Gauche')
            subplot(224)
            findpeaks(marqueurs.RHEE(:,3)*-1, "MinPeakProminence", 10), title('Foot Strike Droit')

            pause;
            disp('Appuyez sur une touche pour continuer');
            close(1);
        end

        if marquagePhaseMarche == 1
            %Localisation du demi-tour
            signal = smoothdata(marqueurDemiTour, 'SmoothingFactor', 0.05);
            ipt = findchangepts(signal,'Statistic', 'linear', 'MinThreshold', 500000);
            [pointMaximal, indiceMaximal] = max(marqueurDemiTour);
            [pointMinimal, indiceMinimal] = min(marqueurDemiTour);
            if indiceMaximal < indiceMinimal % Prise en compte du cas où le demi tour se fait de la droite vers la gauche: inversion des indices minimaux et maximaux.
                x = indiceMaximal;
                y = indiceMinimal;
                indiceMinimal = x;
                indiceMaximal = y;
            end
            frameMilieu = find(marqueurDemiTour(indiceMinimal:indiceMaximal) > ((pointMaximal+pointMinimal)/2)-10 & marqueurDemiTour(indiceMinimal:indiceMaximal) < ((pointMaximal+pointMinimal)/2)+10 , 1); % Entre les points max et min, trouve le point au milieu. Attention, retourne un indice qui ne part pas du début de l'essai.
            frameMilieu = indiceMinimal + frameMilieu; % On rajoute les frame du début de l'essai.
            distanceIptFrameMilieu = ipt - frameMilieu; % Calcul de la distance des points de changement de trajectoire à partir de la frame du milieu de l'essai.
            ipt(1) = (max(distanceIptFrameMilieu(distanceIptFrameMilieu < 0)) + frameMilieu)/frequence;
            ipt(2) = (min(distanceIptFrameMilieu(distanceIptFrameMilieu > 0)) + frameMilieu)/frequence;
            ipt = ipt(1:2);

            %Calcul des écarts de temps entre les foot strike et le début du
            %demi-tour, puis on ne garde que les écarts négatifs (les foot strike situés avant le début du demi-tour. 
            distanceIptFootStrikeGauche = structure.Left_Foot_Strike - ipt(1);
            negFootStrike = distanceIptFootStrikeGauche < 0;
            distanceIptFootStrikeGauche = distanceIptFootStrikeGauche(negFootStrike);

            distanceIptFootStrikeDroit = structure.Right_Foot_Strike - ipt(1);
            negFootStrike = distanceIptFootStrikeDroit < 0;
            distanceIptFootStrikeDroit = distanceIptFootStrikeDroit(negFootStrike);

            %On concatène les écarts à gauche et à droite dans un seul vecteur, on
            %ordonne de manière descendante. Le foot strike le plus proche du
            %demi-tour est alors le premier élément du vecteur.
            distanceIptFootStrike = [distanceIptFootStrikeGauche, distanceIptFootStrikeDroit];
            distanceIptFootStrike = sort(distanceIptFootStrike, 'descend');

            %On détermine le début du demi-tour qui sera marqué: le foot strike qui
            %est le plus proche du début estimé du demi-tour.
            debutDemiTour = distanceIptFootStrike(1) + ipt(1);

            %Calcul des écarts de temps entre les foot off et la fin du
            %demi-tour, puis on ne garde que les écarts positifs (les foot strike situés après la fin du demi-tour. 
            distanceIptFootOffGauche = structure.Left_Foot_Off - ipt(2);
            posFootOff               = distanceIptFootOffGauche > 0;
            distanceIptFootOffGauche = distanceIptFootOffGauche(posFootOff);

            distanceIptFootOffDroit = structure.Right_Foot_Off - ipt(2);
            posFootOff              = distanceIptFootOffDroit > 0;
            distanceIptFootOffDroit = distanceIptFootOffDroit(posFootOff);

            %On concatène les écarts à gauche et à droite dans un seul vecteur, on
            %ordonne. Le foot off le plus proche du
            %demi-tour est alors le premier élément du vecteur.
            distanceIptFootOff = [distanceIptFootOffGauche, distanceIptFootOffDroit];
            distanceIptFootOff = sort(distanceIptFootOff);

            %On détermine le début du demi-tour qui sera marqué: le foot strike qui
            %est le plus proche du début estimé du demi-tour.
            finDemiTour = distanceIptFootOff(1) + ipt(2);


            %Localisation du début de l'aller
            min_Foot(1) = min(structure.Left_Foot_Strike);
            min_Foot(2) = min(structure.Right_Foot_Strike);
            debutAller  = min(min_Foot) - 1/frequence;

            %Localisation de la fin du retour
            max_Foot(1) = max(structure.Left_Foot_Strike);
            max_Foot(2) = max(structure.Right_Foot_Strike);
            finRetour   = max(max_Foot) + 1/frequence;

            structure.General = [debutAller, debutDemiTour, finDemiTour, finRetour];

            for j = 1:length(structure.General)
                btkAppendEvent(acq, 'Event', structure.General(j), 'General');
            end
        end

        % Ecriture des évènements Foot Strike et Foot Off dans la structure
        % contenant les données du C3D
        for j = 1:length(structure.Left_Foot_Strike)
            btkAppendEvent(acq, 'Foot Strike', structure.Left_Foot_Strike(j),'Left');
        end

        for j = 1:length(structure.Right_Foot_Strike)
            btkAppendEvent(acq, 'Foot Strike', structure.Right_Foot_Strike(j),'Right');
        end

        for j = 1:length(structure.Left_Foot_Off)
            btkAppendEvent(acq, 'Foot Off', structure.Left_Foot_Off(j),'Left');
        end

        for j = 1:length(structure.Right_Foot_Off)
            btkAppendEvent(acq, 'Foot Off', structure.Right_Foot_Off(j),'Right');
        end

        % Réécriture du C3D avec les évènements marqués.
        btkWriteAcquisition(acq, listeFichiersC3D(i).name)

        structure = [];
    end
end