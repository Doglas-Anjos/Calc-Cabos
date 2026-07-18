CREATE TABLE cabos (
    id                          SERIAL PRIMARY KEY,
    norma_abnt                  VARCHAR(20)  NOT NULL,
    tipo_cabo                   VARCHAR(50)  NOT NULL,
    tensao_isolamento           VARCHAR(20)  NOT NULL,
    material_isolacao           VARCHAR(20)  NOT NULL,
    material_cobertura          VARCHAR(20),
    temp_max_operacao_c         INTEGER      NOT NULL,
    temp_max_sobrecarga_c       INTEGER      NOT NULL,
    temp_max_curto_circuito     VARCHAR(20)  NOT NULL,
    numero_condutores           VARCHAR(30)  NOT NULL
);

CREATE TABLE metodo_instalacao (
    id                      SERIAL PRIMARY KEY,
    tipo_linha_eletrica     TEXT         NOT NULL,
    numero_metodo           VARCHAR(30)  NOT NULL,
    ref_condutor_isolado    VARCHAR(3),
    ref_cabo_unipolar       VARCHAR(3),
    ref_cabo_multipolar     VARCHAR(3)
);

-- Junction table: links each cable to the installation methods it supports.
-- The applicable reference method per cable category is stored in metodo_instalacao
-- (ref_condutor_isolado, ref_cabo_unipolar, ref_cabo_multipolar).
CREATE TABLE cabos_metodo_instalacao (
    id                      SERIAL       PRIMARY KEY,
    cabos_id                INTEGER      NOT NULL REFERENCES cabos(id),
    metodo_instalacao_id    INTEGER      NOT NULL REFERENCES metodo_instalacao(id),
    UNIQUE (cabos_id, metodo_instalacao_id)
);
