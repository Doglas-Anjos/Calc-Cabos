-- =====================================================================
-- Calc-Cabos — seed do banco de aplicação (calc_cabos_app)
-- =====================================================================

INSERT INTO usuarios (nome, email) VALUES
    ('Usuário Padrão', 'usuario@calc-cabos.local');

INSERT INTO tipo_carga (nome) VALUES
    ('Motor'),
    ('Resistiva'),
    ('Iluminação'),
    ('Outra');
