package com.theincgi.DataCollector;

import javax.sql.DataSource;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;

@Configuration
public class Config {

	@Bean(destroyMethod = "close")
	public DataSource dataSource() {
		HikariConfig config = new HikariConfig();
//		config.setDriverClassName("com.mysql.jdbc.Driver");
		config.setJdbcUrl( String.format("jdbc:%s://%s:%s/%s",
				   System.getenv("database.type"), //mariadb used
				   System.getenv("database.url"), 
				   System.getenv("database.port"), 
				   System.getenv("database.name")));
		config.setUsername(	System.getenv("database.user") );
		config.setPassword( System.getenv("database.pass") );
		
		config.setMaximumPoolSize( 5 );
		config.setConnectionTestQuery("SELECT 1");
		config.setPoolName("springHikariCP");
		
		config.addDataSourceProperty("dataSource.cachePrepStmts", "true");
	    config.addDataSourceProperty("dataSource.prepStmtCacheSize", "250");
	    config.addDataSourceProperty("dataSource.prepStmtCacheSqlLimit", "2048");
	    config.addDataSourceProperty("dataSource.useServerPrepStmts", "true");
		
		return new HikariDataSource(config);
	}
	
}
