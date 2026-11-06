-- panaderia_ep2_completo.sql
-- Sistema de gestion de panaderia - Oracle, 3FN
-- EP2 Taller de BD: modelo + datos + package, procedimientos, funciones y triggers
SET SERVEROUTPUT ON;

-- 0) limpieza (borra tablas/secuencias solo si ya existen)
BEGIN
  FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN
            ('LOG_OPERACION','ALERTA_INSUMO','REGISTRO_ASISTENCIA','PRODUCCION','DETALLE_COMPRA','COMPRA',
             'DETALLE_VENTA','VENTA','RECETA','PRODUCTO','INSUMO','CLIENTE','EMPLEADO',
             'PROVEEDOR','CATEGORIA')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
  FOR q IN (SELECT sequence_name FROM user_sequences WHERE sequence_name IN
            ('SEQ_RECETA','SEQ_VENTA','SEQ_DET_VENTA','SEQ_COMPRA','SEQ_DET_COMPRA',
             'SEQ_PRODUCCION','SEQ_ASISTENCIA')) LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || q.sequence_name;
  END LOOP;
END;
/

-- 1) tablas (en orden de dependencia)
CREATE TABLE categoria (
  id_categoria NUMBER CONSTRAINT pk_categoria PRIMARY KEY,
  nombre       VARCHAR2(60) NOT NULL,
  descripcion  VARCHAR2(200),
  estado       CHAR(1) DEFAULT 'S' NOT NULL
               CONSTRAINT ck_categoria_estado CHECK (estado IN ('S','N'))
);

CREATE TABLE proveedor (
  id_proveedor NUMBER CONSTRAINT pk_proveedor PRIMARY KEY,
  nombre       VARCHAR2(80) NOT NULL,
  rut          VARCHAR2(12) NOT NULL CONSTRAINT uq_proveedor_rut UNIQUE,
  telefono     VARCHAR2(20),
  email        VARCHAR2(80)
);

CREATE TABLE empleado (
  id_empleado   NUMBER CONSTRAINT pk_empleado PRIMARY KEY,
  nombre        VARCHAR2(80) NOT NULL,
  rut           VARCHAR2(12) NOT NULL CONSTRAINT uq_empleado_rut UNIQUE,
  cargo         VARCHAR2(40),
  fecha_ingreso DATE
);

CREATE TABLE cliente (
  id_cliente NUMBER CONSTRAINT pk_cliente PRIMARY KEY,
  nombre     VARCHAR2(80) NOT NULL,
  rut        VARCHAR2(12) CONSTRAINT uq_cliente_rut UNIQUE,
  telefono   VARCHAR2(20)
);

CREATE TABLE insumo (
  id_insumo     NUMBER CONSTRAINT pk_insumo PRIMARY KEY,
  nombre        VARCHAR2(60) NOT NULL,
  unidad_medida VARCHAR2(15),
  stock_actual  NUMBER(10,2) DEFAULT 0 NOT NULL,
  stock_minimo  NUMBER(10,2) DEFAULT 0
);

CREATE TABLE producto (
  id_producto  NUMBER CONSTRAINT pk_producto PRIMARY KEY,
  nombre       VARCHAR2(80) NOT NULL,
  id_categoria NUMBER NOT NULL,
  precio_venta NUMBER(10) NOT NULL,
  stock_actual NUMBER DEFAULT 0 NOT NULL,
  stock_minimo NUMBER DEFAULT 0,
  estado       CHAR(1) DEFAULT 'S' NOT NULL,
  CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria),
  CONSTRAINT ck_producto_estado CHECK (estado IN ('S','N'))
);

CREATE TABLE receta (
  id_receta   NUMBER CONSTRAINT pk_receta PRIMARY KEY,
  id_producto NUMBER NOT NULL,
  id_insumo   NUMBER NOT NULL,
  cantidad    NUMBER(10,3) NOT NULL,
  CONSTRAINT fk_receta_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto),
  CONSTRAINT fk_receta_insumo   FOREIGN KEY (id_insumo)   REFERENCES insumo(id_insumo)
);

CREATE TABLE venta (
  id_venta    NUMBER CONSTRAINT pk_venta PRIMARY KEY,
  id_cliente  NUMBER,
  id_empleado NUMBER NOT NULL,
  fecha       DATE NOT NULL,
  total       NUMBER(12) DEFAULT 0,
  estado      VARCHAR2(15) DEFAULT 'PAGADA',
  CONSTRAINT fk_venta_cliente  FOREIGN KEY (id_cliente)  REFERENCES cliente(id_cliente),
  CONSTRAINT fk_venta_empleado FOREIGN KEY (id_empleado) REFERENCES empleado(id_empleado),
  CONSTRAINT ck_venta_estado CHECK (estado IN ('PAGADA','PENDIENTE','ANULADA'))
);

CREATE TABLE detalle_venta (
  id_detalle_venta NUMBER CONSTRAINT pk_detalle_venta PRIMARY KEY,
  id_venta         NUMBER NOT NULL,
  id_producto      NUMBER NOT NULL,
  cantidad         NUMBER NOT NULL,
  precio_unitario  NUMBER(10) NOT NULL,
  subtotal         NUMBER(12) NOT NULL,
  CONSTRAINT fk_dv_venta    FOREIGN KEY (id_venta)    REFERENCES venta(id_venta),
  CONSTRAINT fk_dv_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto)
);

CREATE TABLE compra (
  id_compra    NUMBER CONSTRAINT pk_compra PRIMARY KEY,
  id_proveedor NUMBER NOT NULL,
  id_empleado  NUMBER,
  fecha        DATE NOT NULL,
  total        NUMBER(12) DEFAULT 0,
  CONSTRAINT fk_compra_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedor(id_proveedor),
  CONSTRAINT fk_compra_empleado  FOREIGN KEY (id_empleado)  REFERENCES empleado(id_empleado)
);

CREATE TABLE detalle_compra (
  id_detalle_compra NUMBER CONSTRAINT pk_detalle_compra PRIMARY KEY,
  id_compra         NUMBER NOT NULL,
  id_insumo         NUMBER NOT NULL,
  cantidad          NUMBER(10,2) NOT NULL,
  precio_unitario   NUMBER(10) NOT NULL,
  subtotal          NUMBER(12) NOT NULL,
  CONSTRAINT fk_dc_compra FOREIGN KEY (id_compra) REFERENCES compra(id_compra),
  CONSTRAINT fk_dc_insumo FOREIGN KEY (id_insumo) REFERENCES insumo(id_insumo)
);

CREATE TABLE produccion (
  id_produccion NUMBER CONSTRAINT pk_produccion PRIMARY KEY,
  id_producto   NUMBER NOT NULL,
  id_empleado   NUMBER NOT NULL,
  fecha         DATE NOT NULL,
  cantidad      NUMBER NOT NULL,
  peso_kg       NUMBER(8,2),
  CONSTRAINT fk_produccion_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto),
  CONSTRAINT fk_produccion_empleado FOREIGN KEY (id_empleado) REFERENCES empleado(id_empleado)
);

CREATE TABLE registro_asistencia (
  id_asistencia NUMBER CONSTRAINT pk_asistencia PRIMARY KEY,
  id_empleado   NUMBER NOT NULL,
  fecha         DATE NOT NULL,
  hora_entrada  VARCHAR2(5),
  hora_salida   VARCHAR2(5),
  CONSTRAINT fk_asistencia_empleado FOREIGN KEY (id_empleado) REFERENCES empleado(id_empleado)
);

-- tablas nuevas EP2 (no estaban en el modelo original)
CREATE TABLE alerta_insumo (
  id_alerta  NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  id_insumo  NUMBER,
  mensaje    VARCHAR2(200),
  fecha      DATE DEFAULT SYSDATE
);

CREATE TABLE log_operacion (
  id_log     NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  tabla      VARCHAR2(30) NOT NULL,
  operacion  VARCHAR2(10) NOT NULL,
  usuario    VARCHAR2(30) DEFAULT USER,
  fecha      DATE         DEFAULT SYSDATE,
  detalle    VARCHAR2(200)
);

-- 2) secuencias
CREATE SEQUENCE seq_receta     START WITH 1;
CREATE SEQUENCE seq_venta      START WITH 1;
CREATE SEQUENCE seq_det_venta  START WITH 1;
CREATE SEQUENCE seq_compra     START WITH 1;
CREATE SEQUENCE seq_det_compra START WITH 1;
CREATE SEQUENCE seq_produccion START WITH 1;
CREATE SEQUENCE seq_asistencia START WITH 1;

-- 3) datos maestros
INSERT INTO categoria VALUES (1, 'Pan',        'Panaderia tradicional',   'S');
INSERT INTO categoria VALUES (2, 'Pasteleria', 'Productos de pasteleria', 'S');
INSERT INTO categoria VALUES (3, 'Galletas',   'Galletas y similares',    'S');
INSERT INTO categoria VALUES (4, 'Tortas',     'Tortas y kuchen',         'S');
INSERT INTO categoria VALUES (5, 'Bebidas',    'Bebidas y cafeteria',     'S');

INSERT INTO proveedor VALUES (1, 'Molino del Sur',        '96.111.111-1', '652-111111', 'ventas@molinodelsur.cl');
INSERT INTO proveedor VALUES (2, 'Lacteos Puerto Montt',  '96.222.222-2', '652-222222', 'contacto@lacteospm.cl');
INSERT INTO proveedor VALUES (3, 'Comercial Dulce SpA',   '96.333.333-3', '652-333333', 'ventas@dulce.cl');
INSERT INTO proveedor VALUES (4, 'Huevos Chiloe',         '96.444.444-4', '652-444444', 'info@huevoschiloe.cl');
INSERT INTO proveedor VALUES (5, 'Distribuidora Austral', '96.555.555-5', '652-555555', 'ventas@austral.cl');
INSERT INTO proveedor VALUES (6, 'Cafe del Sur',          '96.666.666-6', '652-666666', 'contacto@cafedelsur.cl');

INSERT INTO empleado VALUES (1,  'Nicolas Silva',  '18.111.111-1', 'Administrador',    DATE '2022-01-10');
INSERT INTO empleado VALUES (2,  'Maria Gonzalez', '17.222.222-2', 'Maestro panadero', DATE '2021-05-20');
INSERT INTO empleado VALUES (3,  'Pedro Torres',   '19.333.333-3', 'Pastelero',        DATE '2022-03-15');
INSERT INTO empleado VALUES (4,  'Jorge Ampuero',  '16.444.444-4', 'Panadero',         DATE '2021-09-01');
INSERT INTO empleado VALUES (5,  'Luis Cardenas',  '20.555.555-5', 'Panadero',         DATE '2023-02-10');
INSERT INTO empleado VALUES (6,  'Camila Rojas',   '21.666.666-6', 'Vendedor',         DATE '2023-08-01');
INSERT INTO empleado VALUES (7,  'Diego Munoz',    '22.777.777-7', 'Vendedor',         DATE '2024-01-15');
INSERT INTO empleado VALUES (8,  'Fernanda Diaz',  '19.888.888-8', 'Vendedor',         DATE '2024-06-20');
INSERT INTO empleado VALUES (9,  'Valentina Soto', '23.999.999-9', 'Cajero',           DATE '2024-11-05');
INSERT INTO empleado VALUES (10, 'Andrea Vera',    '18.100.100-1', 'Administrativo',   DATE '2023-04-12');

INSERT INTO cliente VALUES (1,  'Cafeteria Central',       '76.101.101-1', '652-901001');
INSERT INTO cliente VALUES (2,  'Hotel Reloncavi',         '76.202.202-2', '652-902002');
INSERT INTO cliente VALUES (3,  'Casino Los Andes',        '76.303.303-3', '652-903003');
INSERT INTO cliente VALUES (4,  'Kiosko La Esquina',       '76.404.404-4', '652-904004');
INSERT INTO cliente VALUES (5,  'Restaurant El Puerto',    '76.505.505-5', '652-905005');
INSERT INTO cliente VALUES (6,  'Cafe Angelmo',            '76.606.606-6', '652-906006');
INSERT INTO cliente VALUES (7,  'Almacen Don Pepe',        '76.707.707-7', '652-907007');
INSERT INTO cliente VALUES (8,  'Hotel Vicente Costanera', '76.808.808-8', '652-908008');
INSERT INTO cliente VALUES (9,  'Juan Perez',              '15.111.222-3', '9-11112222');
INSERT INTO cliente VALUES (10, 'Ana Soto',                '16.222.333-4', '9-22223333');
INSERT INTO cliente VALUES (11, 'Pedro Vargas',            '14.333.444-5', '9-33334444');
INSERT INTO cliente VALUES (12, 'Maria Fuentes',           '17.444.555-6', '9-44445555');
INSERT INTO cliente VALUES (13, 'Carlos Mancilla',         '18.555.666-7', '9-55556666');
INSERT INTO cliente VALUES (14, 'Rosa Oyarzo',             '13.666.777-8', '9-66667777');
INSERT INTO cliente VALUES (15, 'Luis Barria',             '19.777.888-9', '9-77778888');
INSERT INTO cliente VALUES (16, 'Sofia Aguila',            '20.888.999-0', '9-88889999');
INSERT INTO cliente VALUES (17, 'Panaderia Vecina Ltda',   '76.909.909-9', '652-909009');
INSERT INTO cliente VALUES (18, 'Colegio San Javier',      '76.010.010-1', '652-910010');
INSERT INTO cliente VALUES (19, 'Minimarket El Sol',       '76.121.121-2', '652-911011');
INSERT INTO cliente VALUES (20, 'Cliente Boleta',          NULL,           NULL);
INSERT INTO cliente VALUES (21, 'Rotiseria El Trigal',     '76.221.221-2', '652-921021');
INSERT INTO cliente VALUES (22, 'Cafe Literario',          '76.222.222-3', '652-922022');
INSERT INTO cliente VALUES (23, 'Pedro Alvarado',          '15.223.223-4', '9-52223334');
INSERT INTO cliente VALUES (24, 'Comedor Municipal',       '76.224.224-5', '652-924024');
INSERT INTO cliente VALUES (25, 'Sofia Mancilla',          '16.225.225-6', '9-62225556');
INSERT INTO cliente VALUES (26, 'Hostal Puerto Varas',     '76.226.226-7', '652-926026');
INSERT INTO cliente VALUES (27, 'Luis Tapia',              '14.227.227-8', '9-72227778');
INSERT INTO cliente VALUES (28, 'Almacen La Union',        '76.228.228-9', '652-928028');
INSERT INTO cliente VALUES (29, 'Carla Vidal',             '17.229.229-0', '9-82229990');
INSERT INTO cliente VALUES (30, 'Restaurant Mar y Tierra', '76.230.230-1', '652-930030');

-- id, nombre, unidad, stock, minimo
INSERT INTO insumo VALUES (1,  'Harina',      'kg',     2000, 400);
INSERT INTO insumo VALUES (2,  'Azucar',      'kg',     800,  150);
INSERT INTO insumo VALUES (3,  'Mantequilla', 'kg',     300,  60);
INSERT INTO insumo VALUES (4,  'Huevos',      'unidad', 3000, 500);
INSERT INTO insumo VALUES (5,  'Levadura',    'kg',     120,  30);
INSERT INTO insumo VALUES (6,  'Sal',         'kg',     150,  30);
INSERT INTO insumo VALUES (7,  'Leche',       'litro',  500,  100);
INSERT INTO insumo VALUES (8,  'Chocolate',   'kg',     180,  40);
INSERT INTO insumo VALUES (9,  'Manzana',     'kg',     200,  50);
INSERT INTO insumo VALUES (10, 'Crema',       'litro',  160,  40);
INSERT INTO insumo VALUES (11, 'Queso',       'kg',     140,  30);
INSERT INTO insumo VALUES (12, 'Jamon',       'kg',     120,  25);
INSERT INTO insumo VALUES (13, 'Palta',       'kg',     100,  20);
INSERT INTO insumo VALUES (14, 'Cafe grano',  'kg',     90,   20);
INSERT INTO insumo VALUES (15, 'Aceite',      'litro',  130,  30);

-- id, nombre, categoria, precio, stock, minimo, estado
INSERT INTO producto VALUES (1,  'Marraqueta',        1, 200,  1200, 200, 'S');
INSERT INTO producto VALUES (2,  'Hallulla',          1, 180,  1000, 200, 'S');
INSERT INTO producto VALUES (3,  'Pan amasado',       1, 500,  400,  100, 'S');
INSERT INTO producto VALUES (4,  'Pan integral',      1, 600,  300,  80,  'S');
INSERT INTO producto VALUES (5,  'Baguette',          1, 900,  200,  50,  'S');
INSERT INTO producto VALUES (6,  'Empanada de queso', 2, 1500, 250,  60,  'S');
INSERT INTO producto VALUES (7,  'Berlin',            2, 1200, 150,  40,  'S');
INSERT INTO producto VALUES (8,  'Croissant',         2, 1300, 120,  40,  'S');
INSERT INTO producto VALUES (9,  'Sopaipilla',        2, 300,  500,  100, 'S');
INSERT INTO producto VALUES (10, 'Galleta de chips',  3, 800,  300,  60,  'S');
INSERT INTO producto VALUES (11, 'Alfajor',           3, 1000, 200,  50,  'S');
INSERT INTO producto VALUES (12, 'Chilenito',         3, 1100, 150,  40,  'S');
INSERT INTO producto VALUES (13, 'Torta mil hojas',   4, 2500, 40,   10,  'S');
INSERT INTO producto VALUES (14, 'Torta tres leches', 4, 2800, 35,   10,  'S');
INSERT INTO producto VALUES (15, 'Kuchen de manzana', 4, 2200, 30,   10,  'S');
INSERT INTO producto VALUES (16, 'Brazo de reina',    4, 2000, 30,   10,  'S');
INSERT INTO producto VALUES (17, 'Cafe',              5, 1500, 400,  50,  'S');
INSERT INTO producto VALUES (18, 'Jugo natural',      5, 1800, 300,  50,  'S');
COMMIT;

-- 4) recetas (producto <-> insumo)
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 1,  1,  0.050);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 1,  5,  0.005);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 1,  6,  0.002);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 2,  1,  0.050);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 2,  3,  0.010);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 2,  5,  0.004);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 3,  1,  0.100);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 3,  3,  0.020);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 3,  6,  0.003);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 4,  1,  0.100);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 4,  5,  0.005);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 4,  15, 0.010);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 5,  1,  0.120);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 5,  5,  0.006);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 5,  6,  0.003);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 6,  1,  0.080);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 6,  3,  0.030);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 6,  11, 0.050);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 7,  1,  0.060);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 7,  2,  0.030);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 7,  4,  1.000);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 8,  1,  0.070);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 8,  3,  0.040);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 8,  5,  0.004);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 9,  1,  0.040);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 9,  15, 0.020);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 9,  6,  0.002);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 10, 1,  0.030);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 10, 2,  0.020);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 10, 8,  0.015);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 11, 1,  0.040);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 11, 2,  0.025);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 11, 3,  0.015);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 12, 1,  0.040);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 12, 2,  0.030);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 12, 4,  1.000);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 13, 1,  0.090);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 13, 10, 0.050);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 13, 2,  0.040);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 14, 4,  2.000);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 14, 7,  0.100);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 14, 10, 0.060);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 15, 1,  0.080);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 15, 9,  0.150);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 15, 2,  0.030);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 16, 1,  0.070);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 16, 4,  2.000);
INSERT INTO receta VALUES (seq_receta.NEXTVAL, 16, 10, 0.050);
COMMIT;

-- 5) historico de ventas (~8000 ventas, ~2 años)
-- el pan se vende mas que las tortas
DECLARE
  TYPE t_precios IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  v_precio  t_precios;
  v_venta   NUMBER; v_total NUMBER; v_prod NUMBER;
  v_cant    NUMBER; v_nlineas NUMBER; v_r NUMBER; v_estado VARCHAR2(15);
BEGIN
  -- cache de precios (evita miles de SELECT)
  FOR p IN (SELECT id_producto, precio_venta FROM producto) LOOP
    v_precio(p.id_producto) := p.precio_venta;
  END LOOP;

  FOR i IN 1 .. 8000 LOOP
    v_venta := seq_venta.NEXTVAL; v_total := 0;
    v_r := DBMS_RANDOM.VALUE(0,1);
    IF v_r < 0.90 THEN v_estado := 'PAGADA';
    ELSIF v_r < 0.97 THEN v_estado := 'PENDIENTE';
    ELSE v_estado := 'ANULADA';
    END IF;

    INSERT INTO venta (id_venta, id_cliente, id_empleado, fecha, total, estado)
    VALUES (v_venta, TRUNC(DBMS_RANDOM.VALUE(1,31)), TRUNC(DBMS_RANDOM.VALUE(6,11)),
            TRUNC(SYSDATE) - TRUNC(DBMS_RANDOM.VALUE(0,730)), 0, v_estado);

    v_nlineas := TRUNC(DBMS_RANDOM.VALUE(1,6));   -- 1..5 productos por venta
    FOR j IN 1 .. v_nlineas LOOP
      v_r := DBMS_RANDOM.VALUE(0,1);
      IF    v_r < 0.45 THEN v_prod := TRUNC(DBMS_RANDOM.VALUE(1,6));    -- pan
      ELSIF v_r < 0.70 THEN v_prod := TRUNC(DBMS_RANDOM.VALUE(6,10));   -- pasteleria
      ELSIF v_r < 0.85 THEN v_prod := TRUNC(DBMS_RANDOM.VALUE(10,13));  -- galletas
      ELSIF v_r < 0.95 THEN v_prod := TRUNC(DBMS_RANDOM.VALUE(13,17));  -- tortas
      ELSE                  v_prod := TRUNC(DBMS_RANDOM.VALUE(17,19));  -- bebidas
      END IF;

      IF v_prod <= 5 THEN
        v_cant := TRUNC(DBMS_RANDOM.VALUE(2,40));   -- el pan se lleva de a muchos
      ELSE
        v_cant := TRUNC(DBMS_RANDOM.VALUE(1,10));
      END IF;

      INSERT INTO detalle_venta (id_detalle_venta, id_venta, id_producto, cantidad, precio_unitario, subtotal)
      VALUES (seq_det_venta.NEXTVAL, v_venta, v_prod, v_cant, v_precio(v_prod), v_cant * v_precio(v_prod));
      v_total := v_total + (v_cant * v_precio(v_prod));
    END LOOP;

    UPDATE venta SET total = v_total WHERE id_venta = v_venta;
  END LOOP;
  COMMIT;
END;
/

-- 6) historico de compras (~800 compras, ~2 años)
DECLARE
  v_compra NUMBER; v_total NUMBER; v_ins NUMBER;
  v_cant   NUMBER; v_precio NUMBER; v_nlineas NUMBER;
BEGIN
  FOR i IN 1 .. 800 LOOP
    v_compra := seq_compra.NEXTVAL; v_total := 0;
    INSERT INTO compra (id_compra, id_proveedor, id_empleado, fecha, total)
    VALUES (v_compra, TRUNC(DBMS_RANDOM.VALUE(1,7)), TRUNC(DBMS_RANDOM.VALUE(1,11)),
            TRUNC(SYSDATE) - TRUNC(DBMS_RANDOM.VALUE(0,730)), 0);

    v_nlineas := TRUNC(DBMS_RANDOM.VALUE(1,6));
    FOR j IN 1 .. v_nlineas LOOP
      v_ins    := TRUNC(DBMS_RANDOM.VALUE(1,16));
      v_cant   := TRUNC(DBMS_RANDOM.VALUE(20,200));
      v_precio := TRUNC(DBMS_RANDOM.VALUE(500,6000));
      INSERT INTO detalle_compra (id_detalle_compra, id_compra, id_insumo, cantidad, precio_unitario, subtotal)
      VALUES (seq_det_compra.NEXTVAL, v_compra, v_ins, v_cant, v_precio, v_cant * v_precio);
      v_total := v_total + (v_cant * v_precio);
    END LOOP;

    UPDATE compra SET total = v_total WHERE id_compra = v_compra;
  END LOOP;
  COMMIT;
END;
/

-- 7) historico de produccion (~10000 horneadas, ~2 años)
-- solo panaderos/pasteleros (empleados 2..5), productos horneables (1..16)
DECLARE
  v_prod NUMBER; v_r NUMBER;
BEGIN
  FOR i IN 1 .. 10000 LOOP
    v_r := DBMS_RANDOM.VALUE(0,1);
    IF    v_r < 0.55 THEN v_prod := TRUNC(DBMS_RANDOM.VALUE(1,6));    -- pan
    ELSIF v_r < 0.80 THEN v_prod := TRUNC(DBMS_RANDOM.VALUE(6,10));   -- pasteleria
    ELSIF v_r < 0.92 THEN v_prod := TRUNC(DBMS_RANDOM.VALUE(10,13));  -- galletas
    ELSE                  v_prod := TRUNC(DBMS_RANDOM.VALUE(13,17));  -- tortas
    END IF;

    INSERT INTO produccion (id_produccion, id_producto, id_empleado, fecha, cantidad, peso_kg)
    VALUES (seq_produccion.NEXTVAL,
            v_prod,
            TRUNC(DBMS_RANDOM.VALUE(2,6)),
            TRUNC(SYSDATE) - TRUNC(DBMS_RANDOM.VALUE(0,730)),
            TRUNC(DBMS_RANDOM.VALUE(30,400)),
            ROUND(DBMS_RANDOM.VALUE(5,80),2));
  END LOOP;
  COMMIT;
END;
/

-- 8) historico de asistencia (ultimos 540 dias por empleado)
DECLARE
  v_dia DATE;
BEGIN
  FOR e IN (SELECT id_empleado FROM empleado) LOOP
    FOR d IN 1 .. 540 LOOP
      v_dia := TRUNC(SYSDATE) - d;
      -- se salta los domingos (la panaderia cierra)
      IF TO_CHAR(v_dia, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') <> 'SUN' THEN
        INSERT INTO registro_asistencia (id_asistencia, id_empleado, fecha, hora_entrada, hora_salida)
        VALUES (seq_asistencia.NEXTVAL, e.id_empleado, v_dia,
                CASE WHEN DBMS_RANDOM.VALUE(0,1) < 0.5 THEN '07:00' ELSE '08:00' END,
                CASE WHEN DBMS_RANDOM.VALUE(0,1) < 0.5 THEN '16:00' ELSE '17:00' END);
      END IF;
    END LOOP;
  END LOOP;
  COMMIT;
END;
/

-- 9) verificacion: filas por tabla
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'proveedor',           COUNT(*) FROM proveedor
UNION ALL SELECT 'empleado',            COUNT(*) FROM empleado
UNION ALL SELECT 'cliente',             COUNT(*) FROM cliente
UNION ALL SELECT 'insumo',              COUNT(*) FROM insumo
UNION ALL SELECT 'producto',            COUNT(*) FROM producto
UNION ALL SELECT 'receta',              COUNT(*) FROM receta
UNION ALL SELECT 'venta',               COUNT(*) FROM venta
UNION ALL SELECT 'detalle_venta',       COUNT(*) FROM detalle_venta
UNION ALL SELECT 'compra',              COUNT(*) FROM compra
UNION ALL SELECT 'detalle_compra',      COUNT(*) FROM detalle_compra
UNION ALL SELECT 'produccion',          COUNT(*) FROM produccion
UNION ALL SELECT 'registro_asistencia', COUNT(*) FROM registro_asistencia
ORDER BY filas DESC;

SELECT * FROM producto;


-- 10) bloques pl/sql (EP1)

-- record: ficha de un producto
DECLARE
  TYPE t_ficha_producto IS RECORD (
    nombre           producto.nombre%TYPE,
    categoria_nombre categoria.nombre%TYPE,
    stock            producto.stock_actual%TYPE,
    precio           producto.precio_venta%TYPE
  );
  v_ficha t_ficha_producto;
BEGIN
  SELECT p.nombre, c.nombre, p.stock_actual, p.precio_venta
    INTO v_ficha
    FROM producto p
    JOIN categoria c ON c.id_categoria = p.id_categoria
   WHERE p.id_producto = 1;

  DBMS_OUTPUT.PUT_LINE('===== FICHA PRODUCTO (RECORD) =====');
  DBMS_OUTPUT.PUT_LINE('Producto : ' || v_ficha.nombre);
  DBMS_OUTPUT.PUT_LINE('Categoria: ' || v_ficha.categoria_nombre);
  DBMS_OUTPUT.PUT_LINE('Stock    : ' || v_ficha.stock);
  DBMS_OUTPUT.PUT_LINE('Precio   : $' || v_ficha.precio);
END;
/

-- varray: estados posibles de una venta
DECLARE
  TYPE t_estados IS VARRAY(3) OF VARCHAR2(15);
  v_estados t_estados := t_estados('PAGADA','PENDIENTE','ANULADA');
BEGIN
  DBMS_OUTPUT.PUT_LINE('===== ESTADOS DE VENTA (VARRAY) =====');
  FOR i IN 1 .. v_estados.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE('Estado ' || i || ': ' || v_estados(i));
  END LOOP;
END;
/

-- varray de cargos validos + excepcion de usuario
DECLARE
  TYPE t_cargos IS VARRAY(7) OF empleado.cargo%TYPE;
  v_cargos t_cargos := t_cargos('Administrador','Maestro panadero','Pastelero',
                                'Panadero','Vendedor','Cajero','Administrativo');
  v_encontrado BOOLEAN := FALSE;
  p_cargo      empleado.cargo%TYPE := 'Panadero';   -- cambiar para probar
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- Cargos validos (VARRAY) ---');
  FOR i IN 1 .. v_cargos.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE(i || ': ' || v_cargos(i));
    IF v_cargos(i) = p_cargo THEN
      v_encontrado := TRUE;
    END IF;
  END LOOP;

  IF v_encontrado THEN
    DBMS_OUTPUT.PUT_LINE('"' || p_cargo || '" es un cargo valido.');
  ELSE
    RAISE_APPLICATION_ERROR(-20004, 'Cargo no reconocido: ' || p_cargo);
  END IF;
END;
/

-- cursor con parametros + loops anidados: costo de insumos por producto
DECLARE
  CURSOR c_productos IS                         -- maestro (sin parametros)
    SELECT id_producto, nombre FROM producto WHERE estado = 'S' ORDER BY id_producto;

  CURSOR c_insumos(p_id_producto NUMBER) IS     -- detalle (con parametro)
    SELECT r.cantidad,
           NVL((SELECT AVG(precio_unitario) FROM detalle_compra
                 WHERE id_insumo = i.id_insumo), 0) AS precio_prom
      FROM receta r
      JOIN insumo i ON i.id_insumo = r.id_insumo
     WHERE r.id_producto = p_id_producto;

  v_costo_total NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('COSTO DE INSUMOS POR PRODUCTO');
  FOR prod IN c_productos LOOP
    v_costo_total := 0;                          -- reinicio del acumulador
    FOR ins IN c_insumos(prod.id_producto) LOOP
      v_costo_total := v_costo_total + (ins.cantidad * ins.precio_prom);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(RPAD(prod.nombre, 22) || ' costo insumos: $' || ROUND(v_costo_total));
  END LOOP;
END;
/

-- excepcion predefinida 
DECLARE
  v_nombre producto.nombre%TYPE;
BEGIN
  SELECT nombre INTO v_nombre FROM producto WHERE id_producto = 9999;
  DBMS_OUTPUT.PUT_LINE(v_nombre);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Excepcion capturada: el producto no existe (NO_DATA_FOUND)');
END;
/


-- 11) package (EP2)

-- spec
CREATE OR REPLACE PACKAGE pkg_panaderia AS
  FUNCTION fn_total_vendido (p_id_producto IN producto.id_producto%TYPE) RETURN NUMBER;
  FUNCTION fn_costo_producto(p_id_producto IN producto.id_producto%TYPE) RETURN NUMBER;
  FUNCTION fn_insumos_bajo_minimo RETURN NUMBER;

  PROCEDURE sp_vender_producto (p_id_producto IN NUMBER,
                                p_cantidad    IN NUMBER,
                                p_id_empleado IN NUMBER,
                                p_id_cliente  IN NUMBER DEFAULT 20);  -- 20 = cliente boleta
  PROCEDURE sp_registrar_produccion(p_id_producto IN NUMBER,
                                    p_cantidad    IN NUMBER,
                                    p_id_empleado IN NUMBER);
  PROCEDURE sp_recalcular_totales_venta;
END pkg_panaderia;
/

-- body
CREATE OR REPLACE PACKAGE BODY pkg_panaderia AS

  -- privados
  PROCEDURE prc_validar_cantidad(p_cantidad IN NUMBER) IS
  BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
      RAISE_APPLICATION_ERROR(-20010, 'La cantidad debe ser mayor a cero');
    END IF;
  END prc_validar_cantidad;

  FUNCTION fn_insumos_suficientes(p_id_producto IN NUMBER,
                                  p_cantidad    IN NUMBER) RETURN BOOLEAN IS
    v_faltantes NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO v_faltantes
      FROM receta r
      JOIN insumo i ON i.id_insumo = r.id_insumo
     WHERE r.id_producto  = p_id_producto
       AND i.stock_actual < r.cantidad * p_cantidad;
    RETURN v_faltantes = 0;
  END fn_insumos_suficientes;

  -- publicos
  FUNCTION fn_total_vendido(p_id_producto IN producto.id_producto%TYPE) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT NVL(SUM(dv.cantidad), 0)
      INTO v_total
      FROM detalle_venta dv
      JOIN venta v ON v.id_venta = dv.id_venta
     WHERE dv.id_producto = p_id_producto
       AND v.estado <> 'ANULADA';   -- las anuladas no cuentan
    RETURN v_total;
  END fn_total_vendido;

  FUNCTION fn_costo_producto(p_id_producto IN producto.id_producto%TYPE) RETURN NUMBER IS
    v_costo NUMBER;
  BEGIN
    SELECT NVL(SUM(r.cantidad * NVL(pc.precio_prom, 0)), 0)
      INTO v_costo
      FROM receta r
      LEFT JOIN (SELECT id_insumo, AVG(precio_unitario) AS precio_prom
                   FROM detalle_compra
                  GROUP BY id_insumo) pc
             ON pc.id_insumo = r.id_insumo
     WHERE r.id_producto = p_id_producto;
    RETURN ROUND(v_costo);
  END fn_costo_producto;

  FUNCTION fn_insumos_bajo_minimo RETURN NUMBER IS
    v_cant NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_cant
      FROM insumo
     WHERE stock_actual < stock_minimo;
    RETURN v_cant;
  END fn_insumos_bajo_minimo;

  -- sin commit, lo hace quien llama
  PROCEDURE sp_vender_producto(p_id_producto IN NUMBER,
                               p_cantidad    IN NUMBER,
                               p_id_empleado IN NUMBER,
                               p_id_cliente  IN NUMBER DEFAULT 20) IS
    v_stock  producto.stock_actual%TYPE;
    v_precio producto.precio_venta%TYPE;
    v_venta  venta.id_venta%TYPE;
  BEGIN
    prc_validar_cantidad(p_cantidad);

    SELECT stock_actual, precio_venta
      INTO v_stock, v_precio
      FROM producto
     WHERE id_producto = p_id_producto
       AND estado = 'S'
       FOR UPDATE;

    IF v_stock < p_cantidad THEN
      RAISE_APPLICATION_ERROR(-20001, 'Stock insuficiente para el producto ' || p_id_producto ||
                                      ' (disponible: ' || v_stock || ')');
    END IF;

    v_venta := seq_venta.NEXTVAL;

    INSERT INTO venta (id_venta, id_cliente, id_empleado, fecha, total, estado)
    VALUES (v_venta, p_id_cliente, p_id_empleado, SYSDATE, p_cantidad * v_precio, 'PAGADA');

    -- subtotal en 0, lo calcula trg_subtotal_detalle
    INSERT INTO detalle_venta (id_detalle_venta, id_venta, id_producto, cantidad, precio_unitario, subtotal)
    VALUES (seq_det_venta.NEXTVAL, v_venta, p_id_producto, p_cantidad, v_precio, 0);

    UPDATE producto
       SET stock_actual = stock_actual - p_cantidad
     WHERE id_producto = p_id_producto;

    DBMS_OUTPUT.PUT_LINE('Venta ' || v_venta || ' registrada: ' || p_cantidad ||
                         ' unidades, total $' || (p_cantidad * v_precio));
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20002, 'El producto ' || p_id_producto || ' no existe o esta inactivo');
  END sp_vender_producto;

  PROCEDURE sp_registrar_produccion(p_id_producto IN NUMBER,
                                    p_cantidad    IN NUMBER,
                                    p_id_empleado IN NUMBER) IS
    v_lineas_receta NUMBER;
  BEGIN
    prc_validar_cantidad(p_cantidad);

    SELECT COUNT(*) INTO v_lineas_receta
      FROM receta
     WHERE id_producto = p_id_producto;

    IF v_lineas_receta = 0 THEN
      RAISE_APPLICATION_ERROR(-20003, 'El producto ' || p_id_producto || ' no tiene receta registrada');
    END IF;

    IF NOT fn_insumos_suficientes(p_id_producto, p_cantidad) THEN
      RAISE_APPLICATION_ERROR(-20005, 'Insumos insuficientes para producir ' || p_cantidad || ' unidades');
    END IF;

    -- descuenta insumos segun receta (aca se dispara la alerta)
    UPDATE insumo i
       SET i.stock_actual = i.stock_actual -
           (SELECT SUM(r.cantidad) * p_cantidad
              FROM receta r
             WHERE r.id_producto = p_id_producto
               AND r.id_insumo   = i.id_insumo)
     WHERE i.id_insumo IN (SELECT id_insumo FROM receta WHERE id_producto = p_id_producto);

    UPDATE producto
       SET stock_actual = stock_actual + p_cantidad
     WHERE id_producto = p_id_producto;

    INSERT INTO produccion (id_produccion, id_producto, id_empleado, fecha, cantidad, peso_kg)
    VALUES (seq_produccion.NEXTVAL, p_id_producto, p_id_empleado, TRUNC(SYSDATE), p_cantidad, NULL);

    DBMS_OUTPUT.PUT_LINE('Produccion registrada: ' || p_cantidad || ' unidades del producto ' || p_id_producto);
    DBMS_OUTPUT.PUT_LINE('Insumos bajo el minimo: ' || fn_insumos_bajo_minimo);
  END sp_registrar_produccion;

  -- corrige ventas cuyo total no cuadra con el detalle
  PROCEDURE sp_recalcular_totales_venta IS
  BEGIN
    UPDATE venta v
       SET v.total = (SELECT NVL(SUM(dv.subtotal), 0)
                        FROM detalle_venta dv
                       WHERE dv.id_venta = v.id_venta)
     WHERE NVL(v.total, -1) <> (SELECT NVL(SUM(dv.subtotal), 0)
                                  FROM detalle_venta dv
                                 WHERE dv.id_venta = v.id_venta);

    DBMS_OUTPUT.PUT_LINE('Ventas corregidas: ' || SQL%ROWCOUNT);
  END sp_recalcular_totales_venta;

END pkg_panaderia;
/


-- 12) triggers (EP2)

-- fila: alerta solo cuando el insumo baja del minimo
CREATE OR REPLACE TRIGGER trg_alerta_stock_insumo
AFTER UPDATE OF stock_actual ON insumo
FOR EACH ROW
WHEN (NEW.stock_actual < NEW.stock_minimo AND OLD.stock_actual >= OLD.stock_minimo)
BEGIN
  INSERT INTO alerta_insumo (id_insumo, mensaje)
  VALUES (:NEW.id_insumo,
          'Stock bajo de "' || :NEW.nombre || '": ' || :NEW.stock_actual ||
          ' (antes ' || :OLD.stock_actual || ', minimo ' || :NEW.stock_minimo || ')');
END;
/

-- fila before: subtotal
CREATE OR REPLACE TRIGGER trg_subtotal_detalle
BEFORE INSERT OR UPDATE OF cantidad, precio_unitario ON detalle_venta
FOR EACH ROW
BEGIN
  :NEW.subtotal := :NEW.cantidad * :NEW.precio_unitario;
END;
/

-- sentencia: log de venta
CREATE OR REPLACE TRIGGER trg_log_venta
AFTER INSERT OR UPDATE OR DELETE ON venta
DECLARE
  v_op VARCHAR2(10);
BEGIN
  IF INSERTING THEN
    v_op := 'INSERT';
  ELSIF UPDATING THEN
    v_op := 'UPDATE';
  ELSE
    v_op := 'DELETE';
  END IF;

  INSERT INTO log_operacion (tabla, operacion, detalle)
  VALUES ('VENTA', v_op, 'Sentencia ejecutada sobre VENTA');
END;
/

-- revisar que este todo VALID
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('PKG_PANADERIA','TRG_ALERTA_STOCK_INSUMO',
                       'TRG_SUBTOTAL_DETALLE','TRG_LOG_VENTA')
 ORDER BY object_type, object_name;


-- 13) pruebas (al final hay rollback, los datos quedan como estaban)

-- 1. funciones en select
SELECT p.nombre,
       pkg_panaderia.fn_total_vendido(p.id_producto)  AS unidades_vendidas,
       pkg_panaderia.fn_costo_producto(p.id_producto) AS costo_insumos
  FROM producto p
 ORDER BY unidades_vendidas DESC
 FETCH FIRST 10 ROWS ONLY;

SELECT pkg_panaderia.fn_insumos_bajo_minimo AS insumos_criticos FROM dual;

-- 2. venta normal (marraqueta, deberia bajar 10)
SELECT stock_actual AS stock_antes FROM producto WHERE id_producto = 1;
BEGIN
  pkg_panaderia.sp_vender_producto(p_id_producto => 1, p_cantidad => 10, p_id_empleado => 6);
END;
/
SELECT stock_actual AS stock_despues FROM producto WHERE id_producto = 1;
SELECT v.id_venta, v.total, v.estado, dv.cantidad, dv.precio_unitario, dv.subtotal
  FROM venta v JOIN detalle_venta dv ON dv.id_venta = v.id_venta
 WHERE v.id_venta = (SELECT MAX(id_venta) FROM venta);

-- 3. casos que tienen que fallar
BEGIN pkg_panaderia.sp_vender_producto(9999, 1, 6);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Producto inexistente -> ' || SQLERRM); END;
/
BEGIN pkg_panaderia.sp_vender_producto(13, 999999, 6);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Stock insuficiente -> ' || SQLERRM); END;
/
BEGIN pkg_panaderia.sp_vender_producto(1, -5, 6);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Cantidad negativa -> ' || SQLERRM); END;
/
BEGIN pkg_panaderia.sp_vender_producto(1, NULL, 6);
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Cantidad nula -> ' || SQLERRM); END;
/
BEGIN pkg_panaderia.sp_registrar_produccion(17, 10, 2);   -- cafe no tiene receta
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Sin receta -> ' || SQLERRM); END;
/

-- 4. produccion: harina en 410, 300 marraquetas gastan 15 kg -> queda 395 (min 400)
UPDATE insumo SET stock_actual = 410 WHERE id_insumo = 1;
BEGIN
  pkg_panaderia.sp_registrar_produccion(p_id_producto => 1, p_cantidad => 300, p_id_empleado => 2);
END;
/
SELECT id_insumo, nombre, stock_actual, stock_minimo FROM insumo WHERE id_insumo IN (1, 5, 6);
SELECT * FROM alerta_insumo ORDER BY id_alerta;

-- 5. sentencia vs fila: se descuadran 50 ventas y se corrigen
--    el log deberia sumar solo 2 filas (una por cada update)
SELECT COUNT(*) AS logs_antes FROM log_operacion;
UPDATE venta SET total = 0 WHERE id_venta BETWEEN 1 AND 50;
BEGIN
  pkg_panaderia.sp_recalcular_totales_venta;
END;
/
SELECT COUNT(*) AS logs_despues FROM log_operacion;
SELECT * FROM log_operacion ORDER BY id_log;

-- 6. de nuevo, ahora deberia corregir 0
BEGIN
  pkg_panaderia.sp_recalcular_totales_venta;
END;
/

ROLLBACK;


-- 14) consultas de reporte

-- productos mas vendidos
SELECT p.nombre        AS producto,
       SUM(dv.cantidad) AS unidades_vendidas,
       SUM(dv.subtotal) AS ingresos
  FROM detalle_venta dv
  JOIN producto p ON p.id_producto = dv.id_producto
 GROUP BY p.nombre
 ORDER BY unidades_vendidas DESC
 FETCH FIRST 10 ROWS ONLY;

-- detalle de una venta
SELECT v.id_venta, v.fecha, cl.nombre AS cliente, e.nombre AS vendedor, v.estado, v.total
  FROM venta v
  JOIN empleado e ON e.id_empleado = v.id_empleado
  LEFT JOIN cliente cl ON cl.id_cliente = v.id_cliente
 WHERE v.id_venta = 5;

-- ventas pendientes
SELECT id_venta, fecha, total, estado
  FROM venta
 WHERE estado = 'PENDIENTE'
 ORDER BY fecha DESC
 FETCH FIRST 20 ROWS ONLY;

-- produccion por panadero
SELECT e.nombre AS panadero,
       COUNT(pr.id_produccion)  AS registros_produccion,
       ROUND(SUM(pr.peso_kg), 1) AS kilos_totales
  FROM produccion pr
  JOIN empleado e ON e.id_empleado = pr.id_empleado
 GROUP BY e.nombre
 ORDER BY kilos_totales DESC;

-- compras por proveedor
SELECT pv.nombre AS proveedor,
       COUNT(c.id_compra) AS num_compras,
       SUM(c.total)       AS total_comprado
  FROM compra c
  JOIN proveedor pv ON pv.id_proveedor = c.id_proveedor
 GROUP BY pv.nombre
 ORDER BY total_comprado DESC;

-- insumos bajo el minimo
SELECT nombre, stock_actual, stock_minimo,
       (stock_minimo - stock_actual) AS unidades_bajo_el_minimo
  FROM insumo
 WHERE stock_actual < stock_minimo
 ORDER BY unidades_bajo_el_minimo DESC;



-- TURBOMIX