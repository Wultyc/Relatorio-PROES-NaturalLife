USE [NaturalLife]
GO
/****** Object:  StoredProcedure [dbo].[ErroPonto]    Script Date: 16/07/2019 08:48:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[ErroPonto] AS
BEGIN
		DECLARE @SQL table(id int NULL, nome nvarchar(max) NULL, data date NULL)

	insert into @SQL
			-- Número de registos ímpar
			SELECT
				colaboradores.id AS ID,
				colaboradores.nome AS NOME,
				cast(ponto.dataHora as date) AS DATA
				--colaboradores.nome AS 'Nome',
				--COUNT(*) AS 'Contador'
			FROM ponto
			INNER JOIN colaboradores
				ON ponto.colaboradores_id = colaboradores.id
			WHERE cast(ponto.dataHora as date) = cast(GETDATE()-1 as date)
			GROUP BY colaboradores.id, colaboradores.nome, cast(ponto.dataHora as date)
			HAVING COUNT(*) % 2 <> 0
		
			union

			-- Registos com menos de 10 minutos de diferença
			SELECT  P1.colaboradores_id AS 'ID_Colab_RegProx',
					colaboradores.nome AS 'Nome Colab',
					cast(P1.dataHora as date) AS 'Data1'
				   -- MIN(P2.dataHora) AS 'Data2',
					--DATEDIFF(minute, P1.dataHora, MIN(P2.dataHora)) AS 'Diferença'

			FROM ponto as P1
			LEFT JOIN ponto P2 ON P1.colaboradores_id = P2.colaboradores_id
									AND P2.dataHora > P1.dataHora
			INNER JOIN colaboradores
				ON P1.colaboradores_id = colaboradores.id
			WHERE cast(P1.dataHora as date) = cast(GETDATE()-1 as date)
				AND cast(P2.dataHora as date) = cast(GETDATE()-1 as date)
				AND DATEDIFF(minute, P1.dataHora, P2.dataHora) < 10
			GROUP BY P1.colaboradores_id, P1.dataHora, colaboradores.nome

			union

			-- Número de registos de entrada diferente de saída
			SELECT
				colaboradores.id AS ID,
				colaboradores.nome AS NOME,
				cast(ponto.dataHora as date) AS DATA
				--colaboradores.nome AS 'Nome',
				--COUNT(*) AS 'Contador'
			FROM ponto
			INNER JOIN colaboradores
				ON ponto.colaboradores_id = colaboradores.id
			WHERE cast(ponto.dataHora as date) = cast(GETDATE()-1 as date)
			GROUP BY colaboradores.id, colaboradores.nome, cast(ponto.dataHora as date)
			HAVING sum(case when entrada = 1 then 1 else 0 end) <> sum(case when entrada = 0 then 1 else 0 end)

	IF EXISTS(
		SELECT * FROM @SQL
	)
	BEGIN

		--Declara as variaveis
		Declare @HTMLBody nvarchar(max),
				@tableBody nvarchar(max)
	
		--Cria a tabela HTML
		SET @tableBody = CONVERT(NVARCHAR(MAX), (SELECT
			(SELECT '' FOR XML PATH(''), TYPE) AS 'caption',
			(SELECT 
				'ID' AS th,
				'Nome' AS th,
				'Data' AS th,
				'Mais Detalhes' AS th 
				FOR XML RAW('tr'), ELEMENTS, TYPE) AS 'thead',
			(

			--Inicio da Query
			SELECT 
				id as td,
				nome as td,
				data as td,
				cast('<a href = "http://192.168.1.67/Painel/Colaboradores/Ponto/Erro?SearchOnURL=' + cast(id as nvarchar) + '_' + cast(cast(data as date) as nvarchar) + '"  target="_blank"> Ver no Painel </a>' as XML) as td
			
			FROM @SQL
			--Fim da Query
    
			FOR XML RAW('tr'), ELEMENTS, TYPE
			) AS 'tbody'
		FOR XML PATH(''), ROOT('table')));


		--Corpo do HTML
		SET @HTMLBody = '<html><head><style>
			table, th, td {
				border: 1px solid black;
			}
			table {
				width: 100%;
				border-collapse: collapse;
			}
			th {
				width: 25%;
				background-color: #99CCFF;
			}
			tr {
				width: 25%;
				background-color: #F1F1F1;
			}
		</style><title>Registo de Produção maior que Registo de Recolha</title></head><body>'
		--SET @HTMLBody = @HTMLBody + 'Aproxima-se a data do fim de protocolo com os seguintes Pontos de Recolha<br/>'
		SET @HTMLBody = @HTMLBody + @tableBody + '</body></html>'

		--envia o email
		exec msdb.dbo.sp_send_dbmail 
		@profile_name = 'NaturalLife', 
		@recipients = 'naturallife@outlook.pt',
		@subject = '[ALERTA] Erros de Ponto', 
		@body = @HTMLBody, 
		@body_format = 'HTML'

	END
END
