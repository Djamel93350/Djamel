-- Table produits
CREATE TABLE produits (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(255) NOT NULL,
    stock INT NOT NULL
);

-- Table commandes
CREATE TABLE commandes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT NOT NULL,
    date_commande DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Table produits_commandes
CREATE TABLE produits_commandes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    commande_id INT NOT NULL,
    produit_id INT NOT NULL,
    quantite INT NOT NULL,
    FOREIGN KEY (commande_id) REFERENCES commandes(id) ON DELETE CASCADE,
    FOREIGN KEY (produit_id) REFERENCES produits(id) ON DELETE CASCADE
);


-- Insertion des produits
INSERT INTO produits (nom, stock) VALUES
('Produit A', 50),
('Produit B', 30),
('Produit C', 100);

-- Insertion des commandes (à remplir dynamiquement via la procédure)
-- Ces commandes seront associées dynamiquement dans produits_commandes.

-- Insertion des lignes de commande (par commande et produit)
INSERT INTO produits_commandes (commande_id, produit_id, quantite) VALUES
(1, 1, 10),  -- Commande 1 pour 10 unités de Produit A
(1, 2, 5),   -- Commande 1 pour 5 unités de Produit B
(2, 1, 20),  -- Commande 2 pour 20 unités de Produit A
(2, 3, 15);  -- Commande 2 pour 15 unités de Produit C


DELIMITER $$

CREATE PROCEDURE PasserCommande(
    IN p_client_id INT,         -- Identifiant du client
    IN p_produit_id INT,        -- Identifiant du produit
    IN p_quantite INT           -- Quantité demandée
)
BEGIN
    -- Démarrer une transaction
    START TRANSACTION;

    -- Vérifier si le produit est disponible en stock
    DECLARE stock_disponible INT;
    SELECT stock INTO stock_disponible
    FROM produits
    WHERE id = p_produit_id
    FOR UPDATE;  -- Verrouiller la ligne du produit pour éviter des conflits concurrents

    -- Gérer les cas de stock insuffisant ou produit inexistant
    IF stock_disponible IS NULL THEN
        ROLLBACK; -- Annuler la transaction
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Produit introuvable';
    ELSEIF stock_disponible < p_quantite THEN
        ROLLBACK; -- Annuler la transaction
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock insuffisant pour ce produit';
    ELSE
        -- Si le stock est suffisant, déduire la quantité commandée
        UPDATE produits
        SET stock = stock - p_quantite
        WHERE id = p_produit_id;

        -- Créer une nouvelle commande dans la table commandes
        INSERT INTO commandes (client_id, date_commande)
        VALUES (p_client_id, NOW());

        -- Récupérer l'identifiant de la commande créée
        DECLARE new_commande_id INT;
        SET new_commande_id = LAST_INSERT_ID();

        -- Insérer la ligne de commande dans produits_commandes
        INSERT INTO produits_commandes (commande_id, produit_id, quantite)
        VALUES (new_commande_id, p_produit_id, p_quantite);

        -- Valider la transaction
        COMMIT;
    END IF;

END$$

DELIMITER ;
