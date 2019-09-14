/*
 * Copyright (c) 2007, 2018 Oracle and/or its affiliates. All rights reserved.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License v. 2.0, which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * This Source Code may also be made available under the following Secondary
 * Licenses when the conditions for such availability set forth in the
 * Eclipse Public License v. 2.0 are satisfied: GNU General Public License,
 * version 2 with the GNU Classpath Exception, which is available at
 * https://www.gnu.org/software/classpath/license.html.
 *
 * SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
 */

package javax.xml.registry;

import java.util.*;
import java.io.*;

/**
 * This is the abstract base class for factory classes for creating a Jakarta XML Registries connection.
 * A Jakarta XML Registries ConnectionFactory object is configured in a provider-specific way to create connections with registry providers.
 *
 * <h2>Looking Up a ConnectionFactory Using the JNDI API</h2>
 * The preferred way for a client to look up a Jakarta XML Registries ConnectionFactory is within the Java Naming and Directory Interface<sup>TM</sup> (JNDI) API.
 * A ConnectionFactory object is registered with a naming service in a provider specific way, such as one based on the JNDI API. This registration associates the ConnectionFactory object with a logical name. When an application wants to establish a connection with the provider associated with that ConnectionFactory object, it does a lookup, providing the logical name. The application can then use the ConnectionFactory object that is returned to create a connection to the messaging provider.
 *
 * <h2>Looking Up a ConnectionFactory Without Using the JNDI API</h2>
 * The Jakarta XML Registries provides an alternative way to look up a Jakarta XML Registries ConnectionFactory that does not require the use of the JNDI API. This is done using the newInstance static method on the abstract class ConnectionFactory provided in the Jakarta XML Registries API. The newInstance method returns a Jakarta XML Registries ConnectionFactory. The client may indicate which factory class should be instantiated by the newInstance method by defining the system property javax.xml.registry.ConnectionFactoryClass.
 * If this property is not set, the Jakarta XML Registries provider must return a default ConnectionFactory instance.
 *
 *
 * @see Connection
 * @author Farrukh S. Najmi
 */
public abstract class ConnectionFactory {


    /**
     * Sets the Properties used during createConnection
     * and createFederatedConnection calls.
     *
     * <DL>
     * <DT>
     * <B>Standard Connection Properties:</B>
     * <DD><CODE>javax.xml.registry.queryManagerURL</CODE> - URL String for the query manager service within the target registry provider
     * <DD><CODE>javax.xml.registry.lifeCycleManagerURL</CODE> - URL String for the life cycle manager service within the target registry provider. If unspecified, must default to value of the queryManagerURL described above
     * <DD><CODE>javax.xml.registry.semanticEquivalences</CODE> - String that allows specification of semantic equivalences
     * <DD><CODE>javax.xml.registry.security.authenticationMethod</CODE> - string that provides a hint to the Jakarta XML Registries provider on the authentication method to be used when authenticating with the registry provider. Possible value include but are not limited to "UDDI_GET_AUTHTOKEN", "HTTP_BASIC", "CLIENT_CERTIFICATE", "MS_PASSPORT"
     * <DD><CODE>javax.xml.registry.uddi.maxRows</CODE> - integer that specifies the maximum number of rows to be returned for find operations. This property is specific for UDDI providers
     * <DD><CODE>javax.xml.registry.postalAddressScheme</CODE> - String that specifies the id of a ClassificationScheme that is used as the default postal address scheme for this connection
     * </DL>
     * <DL><DT><B>Capability Level: 0 </B></DL>
     *
     * @param properties configuration properties that are either
     * 	specified by Jakarta XML Registries specification or are provider specific.
     * @throws JAXRException	If the Jakarta XML Registries provider encounters an internal error
     *
     */
    public abstract void setProperties(Properties properties) throws JAXRException;

    /**
     * Gets the Properties used during createConnection
     * and createFederatedConnection calls.
     *
     * <DL><DT><B>Capability Level: 0 </B></DL>
     *
     * @return the Properties defined for this object
     * @throws JAXRException	If the Jakarta XML Registries provider encounters an internal error
     *
     */
    public abstract Properties getProperties() throws JAXRException;


    /**
     * Create a named connection. Such a connection can be used to
     * communicate with a Jakarta XML Registries provider.
     *
     * <DL><DT><B>Capability Level: 0 </B></DL>
     *
     * @return the Connection created by this call
     * @throws JAXRException	If the Jakarta XML Registries provider encounters an internal error
     *
     * @see javax.xml.registry.Connection
     */
    public abstract Connection createConnection() throws JAXRException;

    /**
     * Create a FederatedConnection.
     *
     * <DL><DT><B>Capability Level: 0 (optional) </B></DL>
     *
     * @param connections Is a Collection of Connection objects. Note that
     * Connection objects may also be FederatedConnection objects.
     * @return the FederatedConnection created by this call
     * @throws JAXRException	If the Jakarta XML Registries provider encounters an internal error
     *
     *
     * @see javax.xml.registry.FederatedConnection
     */
    public abstract FederatedConnection createFederatedConnection(Collection connections) throws JAXRException;

    /**
     * Creates a default <code>ConnectionFactory</code> object.
     *
     * @return a new instance of a <code>ConnectionFactory</code>
     * @throws JAXRException	If the Jakarta XML Registries provider encounters an internal error
     *
     */
    public static ConnectionFactory newInstance() throws JAXRException {
        try {
            return (ConnectionFactory)
            find(CONNECTION_FACTORY_CLASS, DEFAULT_CONNECTION_FACTORY);
        } catch (Exception ex) {
            throw new JAXRException("Unable to create "+
            "ConnectionFactory: "
            +ex.getMessage());
        }
    }

    private static Object newInstance(String className,
    ClassLoader classLoader)
    throws JAXRException {
        try {
            Class spiClass;
            if (classLoader == null) {
                spiClass = Class.forName(className);
            } else {
                spiClass = classLoader.loadClass(className);
            }
            return spiClass.newInstance();
        } catch (ClassNotFoundException x) {
            throw new JAXRException(
            "Provider " + className + " not found", x);
        } catch (Exception x) {
            throw new JAXRException(
            "Provider " + className + " could not be instantiated: " + x,
            x);
        }
    }

    /**
     * Finds the implementation <code>Class</code> object for the given
     * factory name, or if that fails, finds the <code>Class</code> object
     * for the given fallback class name. The arguments supplied must be
     * used in order. If using the first argument is successful, the second
     * one will not be used.
     * <P>
     * This method is package private so that this code can be shared.
     *
     * @return the <code>Class</code> object of the specified message factory;
     *         may not be <code>null</code>
     *
     * @param factoryId             the name of the factory to find, which is
     *                              a system property
     * @param fallbackClassName     the implementation class name, which is
     *                              to be used only if nothing else
     *                              is found; <code>null</code> to indicate that
     *                              there is no fallback class name
     * @throws JAXRException	If the Jakarta XML Registries provider encounters an internal error
     *
     */
    static Object find(String factoryId, String fallbackClassName)
    throws JAXRException {
        ClassLoader classLoader;
        try {
            classLoader = Thread.currentThread().getContextClassLoader();
        } catch (Exception x) {
            throw new JAXRException(x.toString(), x);
        }

        // Use the system property first
        try {
            String systemProp =
            System.getProperty( factoryId );
            if( systemProp!=null) {
                return newInstance(systemProp, classLoader);
            }
        } catch (SecurityException se) {
        }

        // try to read from $java.home/lib/jaxr.properties
        try {
            String javah=System.getProperty( "java.home" );
            String configFile = javah + File.separator +
            "lib" + File.separator + "jaxr.properties";
            File f=new File( configFile );
            if( f.exists()) {
                Properties props=new Properties();
                FileInputStream pis = new FileInputStream(f);
                try {
                    props.load(pis);
                } finally {
                    pis.close();
                }
                String factoryClassName = props.getProperty(factoryId);
                return newInstance(factoryClassName, classLoader);
            }
        } catch(Exception ex ) {
        }

        String serviceId = "META-INF/services/" + factoryId;
        // try to find services in CLASSPATH
        try {
            InputStream is=null;
            if (classLoader == null) {
                is=ClassLoader.getSystemResourceAsStream(serviceId);
            } else {
                is=classLoader.getResourceAsStream(serviceId);
            }

            if( is!=null ) {
                BufferedReader rd =
                new BufferedReader(new InputStreamReader(is, "UTF-8"));

                String factoryClassName = rd.readLine();
                rd.close();

                if (factoryClassName != null &&
                ! "".equals(factoryClassName)) {
                    return newInstance(factoryClassName, classLoader);
                }
            }
        } catch( Exception ex ) {
        }

        if (fallbackClassName == null) {
            throw new JAXRException(
            "Provider for " + factoryId + " cannot be found", null);
        }

        return newInstance(fallbackClassName, classLoader);
    }

    static private final String CONNECTION_FACTORY_CLASS
    = "javax.xml.registry.ConnectionFactoryClass";

    static private final String DEFAULT_CONNECTION_FACTORY
    = "com.sun.xml.registry.common.ConnectionFactoryImpl";

    /** @link dependency
     * @label creates
     */
    /*#FederatedConnection lnkFederatedConnection;*/
}
